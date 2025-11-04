# Changing to the root of the project
cd ~/Documents/Repositories/bedrock-agentcore-tutorial

# Building the Docker image
echo 'Building the Docker image...'
docker build --platform linux/arm64 -f dependencies/Dockerfile -t strands-agentcore .

# Extracting AWS credentials and region from local AWS config files
AWS_DIR="$HOME/.aws"
CRED_FILE="$AWS_DIR/credentials"
CONF_FILE="$AWS_DIR/config"
PROFILE="default"
AWS_ACCESS_KEY_ID=$(awk "/^\[$PROFILE\]/{flag=1;next}/^\[/{flag=0}flag && /aws_access_key_id/{print \$3}" "$CRED_FILE")
AWS_SECRET_ACCESS_KEY=$(awk "/^\[$PROFILE\]/{flag=1;next}/^\[/{flag=0}flag && /aws_secret_access_key/{print \$3}" "$CRED_FILE")
AWS_DEFAULT_REGION=$(awk "/^\[profile $PROFILE\]/{flag=1;next}/^\[/{flag=0}flag && /region/{print \$3}" "$CONF_FILE")

# Running the Docker container with AWS credentials and region as environment variables
echo -e '\nRunning the Docker container...'
docker run \
    -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    -e AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
    -e OTEL_TRACES_EXPORTER=none \
    -e OTEL_METRICS_EXPORTER=none \
    -e OTEL_LOGS_EXPORTER=none \
    -p 8080:8080 \
    --name strands-agentcore-temp -d strands-agentcore

# Invoking the running Docker container with a sample prompt
sleep 5
echo -e '\nInvoking the Docker container with a sample prompt...'
curl -X POST http://localhost:8080/invocations -H "Content-Type: application/json" -d '{"prompt": "What is the time right now?"}'

# Stopping and removing the Docker container
echo -e '\n\nStopping and removing the Docker container...'
docker stop strands-agentcore-temp
docker rm strands-agentcore-temp
echo -e '\nScript completed.'