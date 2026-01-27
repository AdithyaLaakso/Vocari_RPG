import os
import json
from typing import Optional, List, AsyncGenerator
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from openai import OpenAI
import httpx
import re

app = FastAPI(title="NPC Chatbot Backend", version="1.0.0")

# CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# OpenAI client
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


class ToolCallFunction(BaseModel):
    name: str
    arguments: str

class ToolCall(BaseModel):
    id: str
    type: str = "function"
    function: ToolCallFunction

class ChatMessage(BaseModel):
    role: str
    content: Optional[str] = None  # Can be null for assistant messages with tool calls
    tool_call_id: Optional[str] = None
    tool_calls: Optional[list[ToolCall]] = None

class ToolParameter(BaseModel):
    type: str
    description: Optional[str] = None
    properties: Optional[dict] = None
    required: Optional[list[str]] = None

class ToolFunction(BaseModel):
    name: str
    description: str
    parameters: dict

class Tool(BaseModel):
    type: str = "function"
    function: ToolFunction

class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    tools: list[Tool]
    npc_id: str

class ChatResponse(BaseModel):
    role: str = "assistant"
    content: str
    tool_calls: Optional[list[ToolCall]] = None

@app.get("/")
async def root():
    return {"status": "ok", "message": "NPC Chatbot Backend is running"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

class GrammarCheckRequest(BaseModel):
    text: str
    language: str = "es"  # Default to Spanish
    mother_tongue: Optional[str] = "en"
    level: Optional[str] = None

class GrammarCheckResponse(BaseModel):
    matches: list
    vocab_correct: List[str]
    grammar_patterns: List[str]
    skill_demonstrations: List[str]
    original_text: str
    detected_language: Optional[str] = None

# Vocabulary mapping: Spanish word -> skill ID
VOCAB_MAPPING = {
    "hola": "vocab_greetings_basic",
    "adiós": "vocab_greetings_basic",
    "adios": "vocab_greetings_basic",
    "buenos": "vocab_greetings_basic",
    "días": "vocab_greetings_basic",
    "dias": "vocab_greetings_basic",
    "buenas": "vocab_greetings_basic",
    "tardes": "vocab_greetings_basic",
    "noches": "vocab_greetings_basic",
    "uno": "vocab_numbers_1_10",
    "dos": "vocab_numbers_1_10",
    "tres": "vocab_numbers_1_10",
    "cuatro": "vocab_numbers_1_10",
    "cinco": "vocab_numbers_1_10",
    "seis": "vocab_numbers_1_10",
    "siete": "vocab_numbers_1_10",
    "ocho": "vocab_numbers_1_10",
    "nueve": "vocab_numbers_1_10",
    "diez": "vocab_numbers_1_10",
    "rojo": "vocab_colors_basic",
    "azul": "vocab_colors_basic",
    "verde": "vocab_colors_basic",
    "amarillo": "vocab_colors_basic",
    "negro": "vocab_colors_basic",
    "blanco": "vocab_colors_basic",
    "sí": "vocab_yes_no",
    "si": "vocab_yes_no",
    "no": "vocab_yes_no",
}

# Grammar rule ID -> skill ID mapping
GRAMMAR_MAPPING = {
    "MORFOLOGIK_RULE": "grammar_basic_greetings",  # General spelling/morphology
    "ES_SIMPLE_REPLACE": "grammar_basic_greetings",
}

def extract_vocab_from_text(text: str) -> List[str]:
    """Extract vocabulary skill IDs from text"""
    text_lower = text.lower()
    # Split into words, remove punctuation
    words = re.findall(r'\b\w+\b', text_lower)

    skill_ids = set()
    for word in words:
        if word in VOCAB_MAPPING:
            skill_ids.add(VOCAB_MAPPING[word])

    return list(skill_ids)

def extract_grammar_patterns(matches: list) -> List[str]:
    """Extract grammar pattern skill IDs from LanguageTool matches"""
    skill_ids = set()

    for match in matches:
        rule = match.get("rule", {})
        rule_id = rule.get("id", "")

        # Map rule IDs to skill IDs
        if rule_id in GRAMMAR_MAPPING:
            skill_ids.add(GRAMMAR_MAPPING[rule_id])

    # If no errors, user demonstrated basic grammar skills
    if not matches:
        skill_ids.add("grammar_basic_greetings")

    return list(skill_ids)

def detect_skill_demonstrations(text: str, matches: list) -> List[str]:
    """Detect pragmatic skills demonstrated"""
    text_lower = text.lower()
    skill_ids = set()

    # Greeting detection
    greeting_words = ["hola", "buenos días", "buenas tardes", "buenas noches"]
    if any(word in text_lower for word in greeting_words):
        skill_ids.add("pragmatic_greetings_basic")

    # Farewell detection
    farewell_words = ["adiós", "adios", "hasta luego", "chao"]
    if any(word in text_lower for word in farewell_words):
        skill_ids.add("pragmatic_farewells_basic")

    # Courtesy detection
    courtesy_words = ["por favor", "gracias", "de nada", "perdón", "disculpa"]
    if any(word in text_lower for word in courtesy_words):
        skill_ids.add("pragmatic_courtesy_basic")

    # Basic responses
    response_words = ["sí", "si", "no", "claro", "vale", "ok"]
    if any(word in text_lower for word in response_words):
        skill_ids.add("pragmatic_basic_responses")

    return list(skill_ids)

@app.post("/api/grammar_check", response_model=GrammarCheckResponse)
async def check_grammar(request: GrammarCheckRequest):
    """
    Check grammar using LanguageTool API and extract language learning metrics.
    Proxies to https://vocari.beebs.dev/api/grammar_check
    Falls back to local analysis if external API is unavailable.
    """
    matches = []
    detected_language = None
    api_error = None

    try:
        # Prepare LanguageTool request
        form_data = {
            "text": request.text,
            "language": request.language,
        }

        if request.mother_tongue:
            form_data["motherTongue"] = request.mother_tongue
        if request.level:
            form_data["level"] = request.level

        # Call Vocari grammar check API with shorter timeout
        async with httpx.AsyncClient(timeout=10.0) as http_client:
            response = await http_client.post(
                "https://vocari.beebs.dev/api/grammar_check",
                data=form_data,
            )

            if response.status_code == 200:
                result = response.json()
                matches = result.get("matches", [])
                detected_language = result.get("language", {}).get("detectedLanguage", {}).get("code")
            else:
                api_error = f"API returned status {response.status_code}"
                print(f"Grammar check API error: {api_error}")

    except httpx.TimeoutException:
        api_error = "timeout"
        print("Grammar check API timeout - using local analysis only")
    except httpx.RequestError as e:
        api_error = str(e)
        print(f"Grammar check API unavailable: {api_error} - using local analysis only")
    except Exception as e:
        api_error = str(e)
        print(f"Grammar check error: {api_error} - using local analysis only")

    # Always perform local analysis (works even if API failed)
    vocab_correct = extract_vocab_from_text(request.text)
    grammar_patterns = extract_grammar_patterns(matches)
    skill_demonstrations = detect_skill_demonstrations(request.text, matches)

    return GrammarCheckResponse(
        matches=matches,
        vocab_correct=vocab_correct,
        grammar_patterns=grammar_patterns,
        skill_demonstrations=skill_demonstrations,
        original_text=request.text,
        detected_language=detected_language,
    )

def validate_and_fix_messages(messages: list) -> list:
    """
    Validate message history to ensure tool_calls are properly followed by tool responses.
    OpenAI requires that every tool_call has a corresponding tool response message.
    """
    fixed_messages = []
    pending_tool_calls = {}  # id -> tool_call info

    for msg in messages:
        role = msg.get("role", "")

        if role == "assistant" and msg.get("tool_calls"):
            # Track pending tool calls
            for tc in msg["tool_calls"]:
                pending_tool_calls[tc["id"]] = tc
            fixed_messages.append(msg)

        elif role == "tool":
            # This is a tool response - remove from pending
            tool_call_id = msg.get("tool_call_id")
            if tool_call_id in pending_tool_calls:
                del pending_tool_calls[tool_call_id]
            fixed_messages.append(msg)

        else:
            # Before adding a non-tool message after tool_calls, ensure all are responded to
            if pending_tool_calls:
                # Add dummy responses for any unanswered tool calls
                for tc_id, tc in pending_tool_calls.items():
                    fixed_messages.append({
                        "role": "tool",
                        "tool_call_id": tc_id,
                        "content": f"Tool {tc['function']['name']} executed successfully."
                    })
                pending_tool_calls.clear()
            fixed_messages.append(msg)

    # Handle any remaining pending tool calls at the end
    if pending_tool_calls:
        for tc_id, tc in pending_tool_calls.items():
            fixed_messages.append({
                "role": "tool",
                "tool_call_id": tc_id,
                "content": f"Tool {tc['function']['name']} executed successfully."
            })

    return fixed_messages


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Process a chat request by calling OpenAI API with the provided messages and tools.
    """
    print(f"Received chat request for NPC: {request.npc_id}")
    print(f"Number of messages: {len(request.messages)}")
    print(f"Number of tools: {len(request.tools)}")
    try:
        # Convert messages to OpenAI format
        openai_messages = []
        for msg in request.messages:
            message_dict = {
                "role": msg.role,
                "content": msg.content or "",
            }

            # Handle tool call ID for tool results
            if msg.tool_call_id:
                message_dict["tool_call_id"] = msg.tool_call_id

            # Handle tool calls from assistant
            if msg.tool_calls:
                message_dict["tool_calls"] = [
                    {
                        "id": tc.id,
                        "type": tc.type,
                        "function": {
                            "name": tc.function.name,
                            "arguments": tc.function.arguments,
                        }
                    }
                    for tc in msg.tool_calls
                ]

            openai_messages.append(message_dict)

        # Validate and fix message history to ensure tool_calls have responses
        openai_messages = validate_and_fix_messages(openai_messages)

        # Convert tools to OpenAI format
        openai_tools = [
            {
                "type": tool.type,
                "function": {
                    "name": tool.function.name,
                    "description": tool.function.description,
                    "parameters": tool.function.parameters,
                }
            }
            for tool in request.tools
        ]

        # Call OpenAI API
        response = client.chat.completions.create(
            model="gpt-5-mini",  # Do not change this. it is correct. it should be gpt-5-mini
            messages=openai_messages,
            tools=openai_tools if openai_tools else None,
            tool_choice="auto" if openai_tools else None,
        )

        # Extract the assistant's response
        assistant_message = response.choices[0].message

        # Build response
        result = ChatResponse(
            role="assistant",
            content=assistant_message.content or "",
        )

        # Include tool calls if present
        if assistant_message.tool_calls:
            result.tool_calls = [
                ToolCall(
                    id=tc.id,
                    type=tc.type,
                    function=ToolCallFunction(
                        name=tc.function.name,
                        arguments=tc.function.arguments,
                    )
                )
                for tc in assistant_message.tool_calls
            ]

        return result

    except Exception as e:
        import traceback
        error_detail = f"{type(e).__name__}: {str(e)}\n{traceback.format_exc()}"
        print(f"Error in /chat endpoint: {error_detail}")
        raise HTTPException(status_code=500, detail=error_detail)


class StreamChatRequest(BaseModel):
    messages: list[ChatMessage]
    tools: list[Tool]
    npc_id: str
    message_count: int = 0  # Track conversation turn count for guardrails


async def generate_stream(request: StreamChatRequest) -> AsyncGenerator[str, None]:
    """
    Generate streaming chat response with tool calls.
    Yields SSE formatted data.
    """
    try:
        # Convert messages to OpenAI format
        openai_messages = []
        for msg in request.messages:
            message_dict = {
                "role": msg.role,
                "content": msg.content or "",
            }
            if msg.tool_call_id:
                message_dict["tool_call_id"] = msg.tool_call_id
            if msg.tool_calls:
                message_dict["tool_calls"] = [
                    {
                        "id": tc.id,
                        "type": tc.type,
                        "function": {
                            "name": tc.function.name,
                            "arguments": tc.function.arguments,
                        }
                    }
                    for tc in msg.tool_calls
                ]
            openai_messages.append(message_dict)

        # Validate and fix message history
        openai_messages = validate_and_fix_messages(openai_messages)

        # Convert tools to OpenAI format
        openai_tools = [
            {
                "type": tool.type,
                "function": {
                    "name": tool.function.name,
                    "description": tool.function.description,
                    "parameters": tool.function.parameters,
                }
            }
            for tool in request.tools
        ]

        # Apply guardrails: Only allow tool calls after initial exchange
        # message_count: 0 = NPC opening, 1 = user first message, 2+ = can use tools
        allow_tools = request.message_count >= 2

        # Create streaming response
        stream = client.chat.completions.create(
            model="gpt-5-mini",
            messages=openai_messages,
            tools=openai_tools if openai_tools and allow_tools else None,
            tool_choice="auto" if openai_tools and allow_tools else None,
            stream=True,
        )

        collected_content = ""
        collected_tool_calls = []
        current_tool_call = None

        for chunk in stream:
            delta = chunk.choices[0].delta if chunk.choices else None
            if not delta:
                continue

            # Handle content streaming
            if delta.content:
                collected_content += delta.content
                yield f"data: {json.dumps({'type': 'content', 'content': delta.content})}\n\n"

            # Handle tool calls
            if delta.tool_calls:
                for tc_delta in delta.tool_calls:
                    if tc_delta.index is not None:
                        # New tool call or continuation
                        while len(collected_tool_calls) <= tc_delta.index:
                            collected_tool_calls.append({
                                "id": "",
                                "type": "function",
                                "function": {"name": "", "arguments": ""}
                            })

                        current = collected_tool_calls[tc_delta.index]

                        if tc_delta.id:
                            current["id"] = tc_delta.id
                        if tc_delta.function:
                            if tc_delta.function.name:
                                current["function"]["name"] = tc_delta.function.name
                            if tc_delta.function.arguments:
                                current["function"]["arguments"] += tc_delta.function.arguments

        # Send final message with complete content and any tool calls
        final_response = {
            "type": "done",
            "role": "assistant",
            "content": collected_content,
        }

        if collected_tool_calls:
            final_response["tool_calls"] = [
                {
                    "id": tc["id"],
                    "type": tc["type"],
                    "function": {
                        "name": tc["function"]["name"],
                        "arguments": tc["function"]["arguments"],
                    }
                }
                for tc in collected_tool_calls
            ]

        yield f"data: {json.dumps(final_response)}\n\n"

    except Exception as e:
        import traceback
        error_msg = f"{type(e).__name__}: {str(e)}"
        print(f"Streaming error: {error_msg}\n{traceback.format_exc()}")
        yield f"data: {json.dumps({'type': 'error', 'error': error_msg})}\n\n"


@app.post("/chat/stream")
async def chat_stream(request: StreamChatRequest):
    """
    Streaming chat endpoint using Server-Sent Events (SSE).
    Returns text content as it's generated, then tool calls at the end.
    """
    print(f"Received streaming chat request for NPC: {request.npc_id}")
    print(f"Number of messages: {len(request.messages)}, message_count: {request.message_count}")

    return StreamingResponse(
        generate_stream(request),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        },
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
