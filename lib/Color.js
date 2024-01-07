/**
 * @module Color
 * @description Output text in color
*/
import chalk from "chalk";

const variants = {
  primary: "#0091ff",
  secondary: "#00f7ff",
  success: "#00ff6e",
  warn: "#ffc300",
  danger: "#ff1a00",
  info: "#a100ff",
  debug: "#8E5E92",
  stdout: "#878F87",
  stderr: "#A0655E",
};

export default function color(
  variant,
  text,
  { bold = false, italic = false, underline = false } = {}
) {
  if (!variants[variant]) return text;
  let base = chalk.reset;
  if (bold) base = base.bold;
  if (italic) base = base.italic;
  if (underline) base = base.underline;
  return base.hex(variants[variant])(text);
}
