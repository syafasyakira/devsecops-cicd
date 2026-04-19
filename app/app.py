from flask import Flask, jsonify, render_template
import os
import socket
import datetime

app = Flask(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
BUILD_NUMBER = os.environ.get("BUILD_NUMBER", "local")


@app.route("/")
def index():
    return render_template("index.html",
                           hostname=socket.gethostname(),
                           version=APP_VERSION,
                           build=BUILD_NUMBER,
                           timestamp=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))


@app.route("/health")
def health():
    return jsonify({
        "status": "ok",
        "hostname": socket.gethostname(),
        "version": APP_VERSION,
        "build": BUILD_NUMBER,
        "timestamp": datetime.datetime.now().isoformat()
    }), 200


@app.route("/info")
def info():
    return jsonify({
        "app": "webapp-cicd",
        "version": APP_VERSION,
        "build_number": BUILD_NUMBER,
        "hostname": socket.gethostname(),
        "python_version": os.popen("python --version").read().strip()
    })


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
