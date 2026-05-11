#!/bin/bash
# Snap2Nutrition - AI Server Setup Script (Ollama + LLaVA)
# Run this on your AI server instance (r7.large recommended, 16GB RAM)
# Amazon Linux 2023

exec > /var/log/snap2nutrition-ollama-setup.log 2>&1
set -e

echo "Starting Ollama setup..."

# Update system
dnf update -y
dnf install curl -y

# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Configure Ollama to listen on all network interfaces
# This allows the web server to reach it via private IP
sed -i '/\[Service\]/a Environment="OLLAMA_HOST=0.0.0.0"' /etc/systemd/system/ollama.service

# Reload and start
systemctl daemon-reload
systemctl enable ollama
systemctl start ollama

# Wait for Ollama to be ready
sleep 5

# Pull the LLaVA vision model (~5GB - takes 5-10 minutes)
echo "Pulling LLaVA model..."
ollama pull llava

# Optional: also pull Gemma3 for text-based queries
echo "Pulling Gemma3:4b model..."
ollama pull gemma3:4b

# Confirm
echo "Models installed:"
ollama list

echo "Ollama setup complete! Listening on port 11434"
