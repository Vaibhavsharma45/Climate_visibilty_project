#!/bin/bash

# Climate Visibility App - Quick Setup Script
# This script helps you quickly setup and deploy the application

set -e  # Exit on error

echo "🚀 Climate Visibility App - Quick Setup"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi
print_success "Docker is installed"

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_warning "Docker Compose not found. Trying docker compose..."
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi
print_success "Docker Compose is available"

# Check if .env file exists
if [ ! -f .env ]; then
    print_warning ".env file not found. Creating from .env.example..."
    
    if [ -f .env.example ]; then
        cp .env.example .env
        print_success ".env file created"
        print_warning "⚠️  IMPORTANT: Edit .env file and add your credentials!"
        echo ""
        echo "Please run: nano .env"
        echo "And add your AWS and MongoDB credentials"
        echo ""
        read -p "Press Enter after editing .env file to continue..."
    else
        print_error ".env.example not found. Creating basic .env..."
        cat > .env << EOF
# AWS Credentials
AWS_ACCESS_KEY_ID=your_aws_access_key_here
AWS_SECRET_ACCESS_KEY=your_aws_secret_key_here
AWS_DEFAULT_REGION=us-east-1

# MongoDB Connection
MONGO_DB_URL=mongodb+srv://username:password@cluster.mongodb.net/database_name
EOF
        print_warning "Basic .env created. Please edit it with your credentials!"
        exit 1
    fi
else
    print_success ".env file exists"
fi

# Create necessary directories
echo ""
echo "📁 Creating required directories..."
mkdir -p artifacts/prediction_model
mkdir -p artifacts/data_transformation
mkdir -p logs
print_success "Directories created"

# Build Docker image
echo ""
echo "🔨 Building Docker image..."
if docker build -t climate-visibility:latest .; then
    print_success "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Ask user how they want to run
echo ""
echo "🎯 How do you want to run the application?"
echo "1. Docker Compose (Recommended)"
echo "2. Docker Run (Manual)"
echo "3. Exit"
read -p "Enter your choice [1-3]: " choice

case $choice in
    1)
        echo ""
        echo "🚀 Starting application with Docker Compose..."
        $DOCKER_COMPOSE up -d
        
        if [ $? -eq 0 ]; then
            print_success "Application started successfully!"
            echo ""
            echo "📊 Application is running at: http://localhost:8062"
            echo ""
            echo "Useful commands:"
            echo "  View logs:    $DOCKER_COMPOSE logs -f"
            echo "  Stop app:     $DOCKER_COMPOSE down"
            echo "  Restart app:  $DOCKER_COMPOSE restart"
            echo "  Check status: $DOCKER_COMPOSE ps"
            echo ""
            
            # Wait a bit and check if container is running
            sleep 5
            if $DOCKER_COMPOSE ps | grep -q "Up"; then
                print_success "Container is running! ✨"
                echo ""
                echo "🌐 Opening browser..."
                sleep 2
                
                # Try to open browser (works on macOS and Linux)
                if command -v xdg-open &> /dev/null; then
                    xdg-open http://localhost:8062
                elif command -v open &> /dev/null; then
                    open http://localhost:8062
                fi
            else
                print_error "Container failed to start. Check logs with: $DOCKER_COMPOSE logs"
            fi
        else
            print_error "Failed to start application"
            exit 1
        fi
        ;;
    
    2)
        echo ""
        echo "🚀 Starting application with Docker Run..."
        
        # Stop and remove old container if exists
        docker stop climate-app 2>/dev/null || true
        docker rm climate-app 2>/dev/null || true
        
        # Run new container
        docker run -d \
            --name climate-app \
            -p 8062:8062 \
            --env-file .env \
            -v "$(pwd)/artifacts:/app/artifacts" \
            -v "$(pwd)/logs:/app/logs" \
            --restart unless-stopped \
            climate-visibility:latest
        
        if [ $? -eq 0 ]; then
            print_success "Container started successfully!"
            echo ""
            echo "📊 Application is running at: http://localhost:8062"
            echo ""
            echo "Useful commands:"
            echo "  View logs:    docker logs -f climate-app"
            echo "  Stop app:     docker stop climate-app"
            echo "  Start app:    docker start climate-app"
            echo "  Remove app:   docker rm -f climate-app"
            echo ""
            
            # Wait and check
            sleep 5
            if docker ps | grep -q climate-app; then
                print_success "Container is running! ✨"
            else
                print_error "Container stopped. Check logs with: docker logs climate-app"
            fi
        else
            print_error "Failed to start container"
            exit 1
        fi
        ;;
    
    3)
        echo "Exiting..."
        exit 0
        ;;
    
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
print_success "Setup complete! 🎉"
echo ""
echo "📝 Quick Tips:"
echo "  - Check if app is running: curl http://localhost:8062"
echo "  - View resource usage: docker stats climate-app"
echo "  - Access container shell: docker exec -it climate-app bash"
echo ""