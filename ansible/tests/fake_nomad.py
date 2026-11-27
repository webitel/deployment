#!/usr/bin/env python3
"""Minimal stand-in for the Nomad job API used by roles/nomad/tasks/jobs.yml.

Serves parse, plan, register and read of jobs. Jobs live in the JSON file given
as --state, so a test can change them between runs; every registration is
appended to --log as one JSON line. While the file <state>.bump exists, every
read raises the job's modify index afterwards, as a concurrent change would.
Like Nomad it rejects a job without tasks and answers a failed index check
with 500 "Enforcing job modify index".
"""
import os
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
            return
        self.reply(200, job)
        if os.path.exists(self.server.state + ".bump"):
            jobs = load(self.server.state)
            jobs[job["ID"]]["JobModifyIndex"] += 1
            with open(self.server.state, "w") as f:
                json.dump(jobs, f)

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
                "Tasks": len(re.findall(r'^\s*task "', hcl, re.M)),
                "HCL": hcl,
            })
        elif self.path.endswith("/plan"):
            job = self.body()["Job"]
            if not job["Tasks"]:
                self.reply(500, "Job must have at least one task")
                return
            current = jobs.get(job["ID"])
            same = current is not None and all(current[k] == v for k, v in job.items())
            self.reply(200, {"Diff": {"Type": "None" if same else "Edited"}})
        elif self.path == "/v1/jobs":
            req = self.body()
            job = req["Job"]
            if not job["Tasks"]:
                self.reply(500, "Job must have at least one task")
                return
            current = jobs.get(job["ID"])
            if req.get("EnforceIndex"):
                index = req.get("JobModifyIndex", 0)
                if type(index) is not int:
                    self.reply(400, "Failed to decode request body: cannot unmarshal string into JobModifyIndex of type uint64")
                    return
                if index == 0 and current is not None:
                    self.reply(500, f"Enforcing job modify index {index}: job already exists")
                    return
                if index != 0 and current is None:
                    self.reply(500, f"Enforcing job modify index {index}: job does not exist")
                    return
                if index != 0 and index != current["JobModifyIndex"]:
                    self.reply(500, f"Enforcing job modify index {index}: job exists with conflicting job modify index: "
                                    f"{current['JobModifyIndex']}")
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
