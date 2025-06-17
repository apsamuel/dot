import HelperCli from './lib/cli.js';
import {
  dirname,
  basename,
  resolve as pathResolve
} from 'path'
const cli = new HelperCli();
const __dirname = pathResolve(dirname(''));
console.log(`__dirname: ${__dirname}`);
console.log(process)
const commands = [
  `gh repo create \
    --private \
    --source=. \
    --push \
    noop-inc/${basename(pathResolve(__dirname, '..'))}
  `,
];

for (const command of commands) {
  process.stdout.write(`executing: ${command}\n`);
  // await cli.exec(command);
}
