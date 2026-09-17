from flask import Flask, render_template
import os
import redis

app = Flask(__name__)

redis_host = os.environ.get("REDIS_HOST", "redis")
redis_port = int(os.environ.get("REDIS_PORT", "6379"))

r = redis.Redis(
    host=redis_host,
    port=redis_port,
    decode_responses=True
)


@app.route("/")
def index():
    visits = r.incr("visits")
    return render_template("index.html", visits=visits)


@app.route("/health")
def health():
    return "OK"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
