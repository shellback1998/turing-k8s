import os
import socket
from flask import Flask, jsonify, render_template_string
import redis

app = Flask(__name__)

APP_NAME = os.getenv("APP_NAME", "Equipment Monitor")
APP_VERSION = os.getenv("APP_VERSION", "1.1")
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
    <meta http-equiv="refresh" content="5">

    <style>
        * { box-sizing: border-box; }

        body {
            font-family: Arial, sans-serif;
            max-width: 1000px;
            margin: 40px auto;
            padding: 0 20px;
            background: #f4f6f8;
            color: #20252b;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 6px;
        }

        h1 { margin: 0; }

        .version {
            background: #20252b;
            color: white;
            padding: 7px 12px;
            border-radius: 16px;
            font-size: 14px;
            font-weight: bold;
        }

        .meta {
            color: #666;
            margin-bottom: 24px;
        }

        .runtime {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 12px;
            margin-bottom: 24px;
        }

        .card {
            background: white;
            padding: 16px;
            border-radius: 8px;
            box-shadow: 0 1px 3px rgba(0,0,0,.08);
        }

        .card-label {
            color: #777;
            font-size: 12px;
            text-transform: uppercase;
            margin-bottom: 6px;
        }

        .card-value {
            font-weight: bold;
            overflow-wrap: anywhere;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 1px 3px rgba(0,0,0,.08);
        }

        th, td {
            padding: 14px;
            border-bottom: 1px solid #eee;
            text-align: left;
        }

        th {
            background: #e9ecef;
            font-size: 13px;
            text-transform: uppercase;
        }

        .status {
            display: inline-block;
            padding: 5px 9px;
            border-radius: 12px;
            background: #e9ecef;
            font-size: 13px;
            font-weight: bold;
        }

        .status-running,
        .status-normal,
        .status-open {
            background: #dff3e4;
        }

        .status-standby {
            background: #fff1c7;
        }

        .footer {
            margin-top: 20px;
            color: #777;
            font-size: 13px;
        }
    </style>
</head>

<body>
    <div class="header">
        <h1>{{ app_name }}</h1>
        <div class="version">v{{ app_version }}</div>
    </div>

    <div class="meta">{{ site_name }}</div>

    <div class="runtime">
        <div class="card">
            <div class="card-label">Application Version</div>
            <div class="card-value">{{ app_version }}</div>
        </div>

        <div class="card">
            <div class="card-label">Serving Pod</div>
            <div class="card-value">{{ hostname }}</div>
        </div>

        <div class="card">
            <div class="card-label">Redis Visits</div>
            <div class="card-value">{{ visits }}</div>
        </div>
    </div>

    <table>
        <tr>
            <th>Tag</th>
            <th>Equipment Type</th>
            <th>Status</th>
            <th>Reading</th>
        </tr>

        {% for item in equipment %}
        <tr>
            <td><strong>{{ item.tag }}</strong></td>
            <td>{{ item.type }}</td>
            <td>
                <span class="status status-{{ item.status|lower }}">
                    {{ item.status }}
                </span>
            </td>
            <td>{{ item.value }}</td>
        </tr>
        {% endfor %}
    </table>

    <div class="footer">
        Auto-refresh: 5 seconds •
        Kubernetes multi-replica demonstration
    </div>
</body>
</html>
""",
        app_name=APP_NAME,
        app_version=APP_VERSION,
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
        "version": APP_VERSION,
        "pod": socket.gethostname(),
        "redis": redis_status
    })

@app.route("/api/equipment")
def api_equipment():
    return jsonify(equipment)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
