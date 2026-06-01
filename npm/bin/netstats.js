#!/usr/bin/env node

const fs = require("node:fs");
const https = require("node:https");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");

const owner = "RonnyCao0816";
const repo = "netstats";
const apiURL = `https://api.github.com/repos/${owner}/${repo}/releases/latest`;

const command = process.argv[2] || "help";

if (command === "install") {
  install().catch((error) => {
    console.error(`netstats: ${error.message}`);
    process.exit(1);
  });
} else if (command === "help" || command === "--help" || command === "-h") {
  printHelp();
} else if (command === "version" || command === "--version" || command === "-v") {
  const pkg = require("../package.json");
  console.log(pkg.version);
} else {
  console.error(`netstats: unknown command '${command}'`);
  printHelp();
  process.exit(1);
}

async function install() {
  if (process.platform !== "darwin") {
    throw new Error("NetStats only supports macOS.");
  }

  console.log("Fetching latest NetStats release...");
  const release = await getJSON(apiURL);
  const asset = (release.assets || []).find((item) => /^NetStats-\d+\.\d+\.\d+\.dmg$/.test(item.name));

  if (!asset) {
    throw new Error("No NetStats DMG was found in the latest GitHub Release.");
  }

  const target = path.join(os.tmpdir(), asset.name);
  console.log(`Downloading ${asset.name}...`);
  await download(asset.browser_download_url, target);

  console.log(`Opening ${target}`);
  await run("open", [target]);
  console.log("Drag NetStats.app to Applications when the DMG window opens.");
}

function printHelp() {
  console.log(`NetStats npm helper

Usage:
  npx @ronnycao/netstats install

Commands:
  install      Download and open the latest NetStats DMG
  version      Print this npm package version
  help         Show this help
`);
}

function getJSON(url) {
  return new Promise((resolve, reject) => {
    request(url, (response) => {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        reject(new Error(`GitHub API request failed with status ${response.statusCode}`));
        response.resume();
        return;
      }

      let body = "";
      response.setEncoding("utf8");
      response.on("data", (chunk) => {
        body += chunk;
      });
      response.on("end", () => {
        try {
          resolve(JSON.parse(body));
        } catch (error) {
          reject(new Error(`Could not parse GitHub response: ${error.message}`));
        }
      });
    }).on("error", reject);
  });
}

function download(url, target) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(target);
    request(url, (response) => {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        file.close();
        fs.rm(target, { force: true }, () => {
          download(response.headers.location, target).then(resolve, reject);
        });
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        file.close();
        fs.rm(target, { force: true }, () => {
          reject(new Error(`Download failed with status ${response.statusCode}`));
        });
        return;
      }

      response.pipe(file);
      file.on("finish", () => {
        file.close(resolve);
      });
    }).on("error", (error) => {
      file.close();
      fs.rm(target, { force: true }, () => reject(error));
    });
  });
}

function request(url, callback) {
  return https.get(
    url,
    {
      headers: {
        "Accept": "application/vnd.github+json",
        "User-Agent": "@ronnycao/netstats"
      }
    },
    callback
  );
}

function run(executable, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, args, { stdio: "inherit" });
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${executable} exited with code ${code}`));
      }
    });
  });
}
