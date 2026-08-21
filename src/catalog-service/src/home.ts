import { homedir } from 'node:os';

export function mangoHome(): string {
  return process.env.HOME || homedir();
}
