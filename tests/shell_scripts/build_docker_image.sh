# Changing to the root of the project
cd ~/Documents/Repositories/bedrock-agentcore-tutorial

# Building the Docker image
docker build --platform linux/arm64 -f dependencies/Dockerfile -t strands-agentcore .