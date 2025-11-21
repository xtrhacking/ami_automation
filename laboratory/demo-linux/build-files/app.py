#!/usr/bin/env python3
from flask import Flask, request, jsonify
import os
import subprocess

app = Flask(__name__)

@app.route('/')
def index():
    return jsonify({
        "message": "Welcome to Example Vulnerable API",
        "endpoints": {
            "/ping": "Test network connectivity (GET/POST with 'host' parameter)",
            "/info": "Get system information",
            "/health": "Health check endpoint"
        },
        "warning": "This API contains intentional vulnerabilities for educational purposes"
    })

@app.route('/info')
def info():
    """
    Get basic system information
    """
    return jsonify({
        "hostname": os.uname().nodename,
        "system": os.uname().sysname,
        "release": os.uname().release
    })

@app.route('/health')
def health():
    """
    Health check endpoint
    """
    return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    # Run on all interfaces, port 5000
    app.run(host='0.0.0.0', port=5000, debug=False)
