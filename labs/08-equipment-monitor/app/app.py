import os
import socket
from flask import Flask, jsonify, render_template_string
import redis

app = Flask(__name__)

APP_NAME = os.getenv("APP_NAME", "Equipment Monitor")
SITE_NAME = os.getenv("SITE_NAME", "Turing Pi Lab")
REDIS_HOST = os.getenv("REDIS_HOST", "equipment-redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

equipment = [
    {"tag": "P-101", "type": "Pump",  "status": "Running", "value": "125 GPM"},
    {"tag": "P-102", "type": "Pump",  "status": "Standby", "value": "0 GPM"},
    {"tag": "T-301", "type": "Tank",  "status": "Normal",  "value": "72%"},
    {"tag": "V-401", "type": "Valve", "status": "Open",    "value": "100%"},
]

def redis_client():
    return redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        decode_responses=True,
        socket_connect_timeout=2
    )

@app.route("/")
def index():
    visits = "Unavailable"

    try:
        visits = redis_client().incr("equipment-monitor:visits")
    except redis.RedisError:
        pass

    return render_template_string("""
<!doctype html>
<html>
<head>
    <title>{{ app_name }}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 900px;
            margin: 40px auto;
            padding: 0 20px;
            background: #f4f6f8;
        }
        h1 { margin-bottom: 4px; }
        .meta { color: #666; margin-bottom: 24px; }
        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
        }
        th, td {
            padding: 12px;
            border-bottom: 1px solid #ddd;
            text-align: left;
        }
        th { background: #e9ecef; }
        .footer {
            margin-top: 20px;
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <h1>{{ app_name }}</h1>
    <div class="meta">{{ site_name }}</div>

    <table>
        <tr>
            <th>Tag</th>
            <th>Type</th>
            <th>Status</th>
            <th>Reading</th>
        </tr>
        {% for item in equipment %}
        <tr>
            <td>{{ item.tag }}</td>
            <td>{{ item.type }}</td>
            <td>{{ item.status }}</td>
            <td>{{ item.value }}</td>
        </tr>
        {% endfor %}
    </table>

    <div class="footer">
        Pod: {{ hostname }} |
        Visits: {{ visits }}
    </div>
</body>
</html>
""",
        app_name=APP_NAME,
        site_name=SITE_NAME,
        equipment=equipment,
        hostname=socket.gethostname(),
        visits=visits
    )

@app.route("/health")
def health():
    redis_status = "ok"

    try:
        redis_client().ping()
    except redis.RedisError:
        redis_status = "unavailable"

    return jsonify({
        "status": "ok",
        "application": APP_NAME,
        "pod": socket.gethostname(),
        "redis": redis_status
    })

@app.route("/api/equipment")
def api_equipment():
    return jsonify(equipment)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
