# Using the official Astral UV Python 3.12 slim image as the base image
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# Setting working directory
WORKDIR /app

# Copying requirements and install dependencies using uv
COPY dependencies/requirements.txt ./requirements.txt
RUN uv pip install --system -r requirements.txt

# Copying the source code
COPY src/ ./src/

# Setting entrypoint
ENTRYPOINT ["opentelemetry-instrument", "python", "src/strands_agentcore.py"]