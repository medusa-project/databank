import path from "node:path";
import { existsSync } from "node:fs";

export const PLAYWRIGHT_ROLES = ["depositor", "no_deposit", "admin", "guest"];
export const NAMED_USERS = [
  {
    id: "researcher1",
    role: "depositor",
    name: "Researcher1",
    email: "researcher1@mailinator.com",
  },
  {
    id: "undergrad1",
    role: "no_deposit",
    name: "Undergrad1",
    email: "undergrad1@mailinator.com",
  },
  {
    id: "curator1",
    role: "admin",
    name: "Curator1",
    email: "curator1@mailinator.com",
  },
  {
    id: "guest",
    role: "guest",
    name: "Guest",
    email: "guest@mailinator.com",
  },
];

const AUTH_DIR = path.join(process.cwd(), "playwright", ".auth");

function sanitizeForFile(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function authStatePath(role) {
  return path.join(AUTH_DIR, `${role}.json`);
}

export function namedAuthStatePath(role, email) {
  const safeRole = sanitizeForFile(role);
  const safeEmail = sanitizeForFile(email);
  return path.join(AUTH_DIR, `${safeRole}--${safeEmail}.json`);
}

export function hasNamedAuthState(role, email) {
  return existsSync(namedAuthStatePath(role, email));
}

export function getNamedAuthState(role, email) {
  const target = namedAuthStatePath(role, email);
  return existsSync(target) ? target : null;
}

export function getNamedAuthStateById(id) {
  const user = NAMED_USERS.find((entry) => entry.id === id);
  if (!user) {
    return null;
  }

  return getNamedAuthState(user.role, user.email);
}
