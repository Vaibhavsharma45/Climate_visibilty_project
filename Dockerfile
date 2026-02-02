# Use Python 3.9 slim image
FROM python:3.9-slim-buster

# Set working directory
WORKDIR /app

# Copy requirements first (better caching)
COPY requirements.txt /app/

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install AWS CLI (if needed)
RUN pip install --no-cache-dir awscli

# Copy application code
COPY . /app

# Create non-root user for security
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port (adjust if needed)
EXPOSE 8062

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8062/', timeout=2)" || exit 1

# Run the application
CMD ["python3", "app.py"]