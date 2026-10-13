import os
import socket
from flask import Flask, jsonify

app = Flask(__name__)
VERSION = os.environ.get("APP_VERSION", "dev")

@app.route("/")
def home():
    return f"Hello from k8s-aws-portfolio! Version: {VERSION}\n"

@app.route("/health")
def health():
    return jsonify(status="ok")

@app.route("/version")
def version():
    return jsonify(version=VERSION, host=socket.gethostname())

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)