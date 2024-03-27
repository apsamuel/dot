import Command from "./lib/Command.js";
const command = new Command();
const results = await command.spawn("ls", ["-l"])
console.log(results.stdout)