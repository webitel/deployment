#!/usr/bin/env python3
"""Minimal stand-in for the Nomad job API used by roles/nomad/tasks/jobs.yml.

Serves parse, plan, register and read of jobs. Jobs live in the JSON file given
as --state, so a test can change them between runs; every registration is
appended to --log as one JSON line.
"""
import argparse
import json
import re
from http.server import BaseHTTPRequestHandler, HTTPServer


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def body(self):
        return json.loads(self.rfile.read(int(self.headers["Content-Length"])))

    def do_GET(self):
        job = load(self.server.state).get(self.path.rsplit("/", 1)[-1])
        if job is None:
            self.reply(404, "job not found")
        else:
            self.reply(200, job)

    def do_POST(self):
        jobs = load(self.server.state)
        if self.path == "/v1/jobs/parse":
            hcl = self.body()["JobHCL"]
            name = re.search(r'^job "([^"]+)"', hcl, re.M).group(1)
            self.reply(200, {
                "ID": name,
                "Type": re.search(r'^\s*type\s*=\s*"(\w+)"', hcl, re.M).group(1),
                "Stop": False,
                "Meta": dict(re.findall(r'^\s*(\w+)\s*=\s*"([^"]*)"$', hcl.split("group")[0], re.M)),
                "HCL": hcl,
            })
        elif self.path.endswith("/plan"):
            job = self.body()["Job"]
            current = jobs.get(job["ID"])
            same = current is not None and all(current[k] == v for k, v in job.items())
            self.reply(200, {"Diff": {"Type": "None" if same else "Edited"}})
        elif self.path == "/v1/jobs":
            req = self.body()
            job = req["Job"]
            current = jobs.get(job["ID"])
            if req.get("EnforceIndex") and (current or {}).get("JobModifyIndex") != req.get("JobModifyIndex"):
                self.reply(409, "job modify index conflict")
                return
            job["JobModifyIndex"] = (current or {}).get("JobModifyIndex", 0) + 1
            jobs[job["ID"]] = job
            with open(self.server.state, "w") as f:
                json.dump(jobs, f)
            with open(self.server.log, "a") as f:
                f.write(json.dumps({"id": job["ID"], "stop": job["Stop"],
                                    "enforce": bool(req.get("EnforceIndex"))}) + "\n")
            self.reply(200, {"EvalID": "e"})
        else:
            self.reply(404, "unknown path")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--state", required=True)
    ap.add_argument("--log", required=True)
    ap.add_argument("--port-file", required=True)
    args = ap.parse_args()
    server = HTTPServer(("127.0.0.1", 0), Handler)
    server.state, server.log = args.state, args.log
    with open(args.port_file, "w") as f:
        f.write(str(server.server_port))
    server.serve_forever()


if __name__ == "__main__":
    main()
