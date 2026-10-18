import os
import socket
from datetime import datetime, timezone

from flask import Flask, Response, jsonify, render_template_string, request

app = Flask(__name__)
VERSION = os.environ.get("APP_VERSION", "dev")


def info():
    return {
        "greeting": os.environ.get("GREETING", "Hello"),
        "version": VERSION,
        "pod": os.environ.get("POD_NAME", socket.gethostname()),
        "node": os.environ.get("NODE_NAME", "local"),
        "pod_ip": os.environ.get("POD_IP", "n/a"),
        "time": datetime.now(timezone.utc).strftime("%H:%M:%S UTC"),
    }


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>k8s-aws-portfolio</title>
<style>
  :root { --bg:#0f172a; --card:#1e293b; --text:#e2e8f0; --muted:#94a3b8; --accent:#38bdf8; }
  * { box-sizing:border-box; }
  body { margin:0; font-family:system-ui,-apple-system,"Segoe UI",sans-serif; background:var(--bg); color:var(--text); }
  main { max-width:760px; margin:0 auto; padding:2rem 1rem; }
  h1 { margin:0 0 .25rem; font-size:1.8rem; }
  .sub { color:var(--muted); margin:0 0 1.5rem; }
  .card { background:var(--card); border-radius:12px; padding:1.25rem; margin-bottom:1rem; }
  .card h2 { margin:0 0 .75rem; font-size:.9rem; color:var(--muted); text-transform:uppercase; letter-spacing:.05em; display:flex; justify-content:space-between; align-items:center; }
  dl { display:grid; grid-template-columns:max-content 1fr; gap:.4rem 1rem; margin:0; }
  dt { color:var(--muted); }
  dd { margin:0; font-family:ui-monospace,Consolas,monospace; overflow-wrap:anywhere; }
  .bars div { display:flex; align-items:center; gap:.5rem; margin:.3rem 0; font-family:ui-monospace,Consolas,monospace; font-size:.85rem; }
  .bar { height:10px; border-radius:5px; transition:width .4s; }
  ol { list-style:none; margin:0; padding:0; font-family:ui-monospace,Consolas,monospace; font-size:.85rem; }
  li { padding:.3rem 0; border-bottom:1px solid #334155; }
  .dot { display:inline-block; width:.6rem; height:.6rem; border-radius:50%; margin-right:.5rem; }
  .new { color:#fbbf24; font-weight:700; }
  button { background:var(--accent); color:#0f172a; border:0; border-radius:8px; padding:.35rem .9rem; font-weight:600; cursor:pointer; }
  footer { color:var(--muted); font-size:.8rem; margin-top:1.5rem; }
</style>
</head>
<body>
<main>
  <h1>{{ i.greeting }} from k8s-aws-portfolio!</h1>
  <p class="sub">Served by one of several Kubernetes pods. Watch live traffic spread across them below.</p>

  <section class="card">
    <h2>This page was served by</h2>
    <dl>
      <dt>Pod</dt><dd>{{ i.pod }}</dd>
      <dt>Node</dt><dd>{{ i.node }}</dd>
      <dt>Pod IP</dt><dd>{{ i.pod_ip }}</dd>
      <dt>Version</dt><dd title="{{ i.version }}">{{ i.version[:7] }}</dd>
    </dl>
  </section>

  <section class="card">
    <h2>Requests per pod</h2>
    <div class="bars" id="bars"></div>
  </section>

  <section class="card">
    <h2>Live requests <button id="toggle">Pause</button></h2>
    <ol id="log"></ol>
  </section>

  <footer>Flask + gunicorn · Docker · GitHub Actions · Trivy · Amazon ECR · Kubernetes on EKS · Terraform</footer>
</main>
<script>
  const firstVersion = {{ i.version | tojson }};
  const counts = {};
  const log = document.getElementById("log");
  const bars = document.getElementById("bars");
  let running = true;

  function color(name) {
    let h = 0;
    for (const c of name) h = (h * 31 + c.charCodeAt(0)) % 360;
    return `hsl(${h} 70% 60%)`;
  }

  function drawBars() {
    const max = Math.max(...Object.values(counts));
    bars.replaceChildren(...Object.entries(counts).map(([pod, n]) => {
      const row = document.createElement("div");
      const bar = document.createElement("span");
      bar.className = "bar";
      bar.style.width = `${(n / max) * 60}%`;
      bar.style.background = color(pod);
      const label = document.createElement("span");
      label.textContent = `${pod.slice(-5)} · ${n}`;
      row.append(bar, label);
      return row;
    }));
  }

  async function poll() {
    if (!running) return;
    try {
      const r = await fetch("/api/info", { cache: "no-store" });
      const d = await r.json();
      counts[d.pod] = (counts[d.pod] || 0) + 1;
      const li = document.createElement("li");
      const dot = document.createElement("span");
      dot.className = "dot";
      dot.style.background = color(d.pod);
      li.append(dot, `${d.time}  ${d.pod}  ${d.version.slice(0, 7)}`);
      if (d.version !== firstVersion) {
        const tag = document.createElement("span");
        tag.className = "new";
        tag.textContent = "  NEW VERSION";
        li.append(tag);
      }
      log.prepend(li);
      while (log.children.length > 12) log.lastChild.remove();
      drawBars();
    } catch (e) {
      const li = document.createElement("li");
      li.textContent = "request failed";
      log.prepend(li);
    }
  }

  document.getElementById("toggle").onclick = (e) => {
    running = !running;
    e.target.textContent = running ? "Pause" : "Resume";
  };
  setInterval(poll, 1500);
  poll();
</script>
</body>
</html>"""


@app.route("/")
def index():
    i = info()
    if "text/html" in request.headers.get("Accept", ""):
        return render_template_string(PAGE, i=i)
    text = f"{i['greeting']} from k8s-aws-portfolio! Version: {i['version']} Pod: {i['pod']}\n"
    return Response(text, mimetype="text/plain")


@app.route("/api/info")
def api_info():
    resp = jsonify(info())
    resp.headers["Cache-Control"] = "no-store"
    return resp


@app.route("/health")
def health():
    return "ok"


@app.route("/version")
def version():
    return jsonify(version=VERSION, hostname=socket.gethostname())