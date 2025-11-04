import boto3
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent, tool
from strands.models import BedrockModel
from strands_tools import calculator, current_time
from opentelemetry import baggage, context

# Instantiating the model from AWS Bedrock
bedrock_model = BedrockModel(
    model_id="us.anthropic.claude-haiku-4-5-20251001-v1:0",
    region_name="us-east-1",
    temperature=0.7,
)

# Defining a custom tool as a Python function using the @tool decorator
@tool
def letter_counter(word: str, letter: str) -> int:
    """
    Count occurrences of a specific letter in a word.

    Args:
        word (str): The input word to search in
        letter (str): The specific letter to count

    Returns:
        int: The number of occurrences of the letter in the word
    """
    if not isinstance(word, str) or not isinstance(letter, str):
        return 0

    if len(letter) != 1:
        raise ValueError("The 'letter' parameter must be a single character")

    return word.lower().count(letter.lower())

# Creating an agent with tools built-in Strands tools and the custom tool
agent = Agent(model=bedrock_model, tools=[calculator, current_time, letter_counter])

# Initialize the Bedrock AgentCore App
app = BedrockAgentCoreApp()

@app.entrypoint
def invoke(payload):
    """Process user input and return a response"""
    user_message = payload.get("prompt", "Hello")
    
    # Set session ID for OTEL if provided
    session_id = payload.get("session_id")
    if session_id:
        ctx = baggage.set_baggage("session.id", session_id)
        context.attach(ctx)
    
    result = agent(user_message)
    return {"result": str(result.message)}

if __name__ == "__main__":
    app.run()

# To invoke the app, use the command:
# curl -X POST http://localhost:8080/invocations -H "Content-Type: application/json" -d '{"prompt": "What is the time right now?"}'