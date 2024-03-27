/**
 * @module Command
 * @description Execute commands and files in workflows
*/
import { exec, execFile, spawn } from "child_process";
import { inspect, promisify } from "util";
import color from "./Color.js";


import { resolve } from "path";
import * as emoji from "node-emoji";

export default class Command {
  #defaults = {
    detached: true,
    cwd: resolve(),
  };

  #options = {
    stdout: [],
    stderr: [],
    code: 0,
    message: "",
    stack: [],
    signal: null,
    killed: false,
  }

  constructor(props = {}) {
    Object.assign(this, props);
    this.controller = props.controller || new AbortController();
    this.history = props.history || [];
    this.defaults = props.defaults || this.#defaults;
    this.options = props.options || this.#options;
    this.environment = props.environment || process.env;
  }

  /**
   * @description spawn a command
   * @param {string} command
   * @param {string[]} args
   * @param {object} options
   * @returns {Promise<CommandResult>}
  */
  async spawn(command, args = [], options = {}) {
    if (!options.detached) options.detached = false;
    const { signal } = this.controller;
    const env = options.env || this.environment;
    var ret = {
      stdout: [],
      stderr: [],
      code: 0,
      message: "",
      stack: [],
      signal: null,
      killed: false,
      cmd: command,
      args,
    };

    return new Promise(function (resolve, reject) {
      const child = spawn(command, args, {
        env,
        signal,
        detached: options?.detached,
        ...options,
      });
      child.stdout.on("data", (data) => {
        if (data.toString().split("\n") > 0) {
          for (const line of data.toString().split("\n")) {
            console.log(typeof line);
            ret.stdout.push(line.trim());
          }
        } else {
          ret.stdout.push(data.toString().trim());
        }
      });
      child.stderr.on("data", (data) => {
        if (data.toString().split("\n") > 0) {
          for (const line of data.toString().split("\n")) {
            ret.stdout.push(line.trim());
          }
        } else {
          ret.stdout.push(data.toString().trim());
        }
      });
      child.on("close", (code) => {
        ret.code = code;
        if (code === 0) {
          resolve(new CommandResult(ret));
        } else {
          resolve(new CommandResult(ret));
        }
      });
      child.on("error", (error) => {
        // ret.error = { ...error }
        ret.code = error.errno;
        ret.stack = [...error.stack.split("\n")];
        ret.message = error.message;
        // reject(ret);
        resolve(new CommandResult(ret));
      });
    });
  }

  /**
   * @description execute a command
   * @param {string} command
   * @param {object} options
   * @returns {Promise<CommandResult>}
  */
  async exec(command, options = {}) {
    if (!options.detached) options.detached = false;
    const { signal } = this.controller;
    try {
      /*
      properly use promisify https://nodejs.org/dist/latest-v8.x/docs/api/util.html#util_util_promisify_original
      */
      const asyncExec = promisify(exec);
      const execution = await asyncExec(command, {
        signal,
        ...options,
      })
      // const execution = await promisify(exec, {
      //   signal,
      //   ...options,
      // })(command);
      const result = new CommandResult({
        ...execution,
        stdout: execution.stdout.trim(),
        stderr: execution.stderr.trim(),
        stack: [],
        message: "success",
        code: 0,
        signal: null,
        cmd: command,
        killed: false,
      });
      this.history.push({
        type: "exec",
        ...result,
      });
      return result;
    } catch (error) {
      const result = new CommandResult({
        ...error,
        stdout: error.stdout.trim(),
        stderr: error.stderr.trim(),
        stack: error.stack.split("\n").filter((line) => {
          if (line) return line;
        }),
        message: error.message.split("\n").filter((line) => {
          if (line) return line;
        }),
      });
      this.history.push({
        type: "exec",
        ...result,
      });
      return result;
    }
  }

  /**
   * @description execute a file
   * @param {string} path
   * @param {string[]} args
   * @param {object} options
   * @returns {Promise<CommandResult>}
  */
  async execFile(path, args = [], options = {}) {
    const { signal } = this.controller;
    const res = {
      stdout: [],
      stderr: [],
      stack: [],
      message: "success",
      code: 0,
      signal: null,
      path,
      args,
      killed: false,
    };
    try {
      const stat = await stat(path);
      const env = process.env;
      const execution = await promisify(execFile)(path, args, {
        signal,
        ...options,
        env,
      });
      return new CommandResult({
        ...res,
        ...execution,
      });
    } catch (e) {
      return new CommandResult({
        ...res,
        code: e.errno,
        message: e.toString(),
      });
    }
  }

  [inspect.custom](depth, options) {
    return [
      color("secondary", `[${this.constructor.name} `, { bold: true }),
      color(
        "primary",
        `${emoji.get("wrench")} historyItems: ${
          this.history.length
        } environmentVariables: ${Object.keys(this.environment).length}`,
        { bold: false }
      ),
      color("secondary", "]", { bold: true }),
    ].join("");
  }
}

/**
 * CommandResult provides a consistent interface what is returned from a Command command
*/
export class CommandResult {
  constructor(props) {
    Object.assign(this, props);
  }

  /**
   * check if command was successful
   * @returns {boolean}
  */
  success() {
    return this.code === 0;
  }

  /**
   * get stdout lines
   * @returns {string[]}
  */
  lines() {
    if (this.stdout) return this.stdout.split("\n");
  }

  [inspect.custom](depth, options) {
    return [
      color("secondary", `${this.constructor.name} `, { bold: true }),
      color(
        "primary",
        `command: '${this.cmd}' exitCode: ${
          this.code === 0 ? emoji.get("rocket") : emoji.get("bomb")
        } (${this.code}) isKilled: ${
          this.killed ? emoji.get("skull") : emoji.get("smile")
        } (${this.killed ? "dead" : "alive"})`,
        { bold: false }
      ),
    ].join("");
  }
}
