const { spawn } = require("node:child_process");

const executable = process.argv[2];
if (!executable) {
  throw new Error("Usage: node test-node-spawn.js <native-HLS-launcher>");
}

const child = spawn(executable, ["--numeric-version"], {
  shell: false,
  stdio: ["ignore", "pipe", "pipe"],
});

let stdout = "";
let stderr = "";
child.stdout.on("data", (chunk) => (stdout += chunk));
child.stderr.on("data", (chunk) => (stderr += chunk));
child.on("error", (error) => {
  console.error(error);
  process.exitCode = 1;
});
child.on("close", (code) => {
  if (code !== 0 || !/\d+\.\d+/.test(stdout)) {
    console.error(`Native launcher failed (exit ${code}).\nstdout: ${stdout}\nstderr: ${stderr}`);
    process.exitCode = 1;
    return;
  }
  console.log(`Node spawn OK: ${stdout.trim()}`);
});
