import * as SecureStore from "expo-secure-store";

const GITHUB_API = "https://api.github.com";

async function getToken(): Promise<string> {
  const token = await SecureStore.getItemAsync("GITHUB_TOKEN");
  if (!token) throw new Error("GITHUB_TOKEN missing. Set it in Settings first.");
  return token;
}

function authHeaders(token: string) {
  return {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
  };
}

export async function testGithubConnection(): Promise<{ login: string }> {
  const token = await getToken();
  const res = await fetch(`${GITHUB_API}/user`, { headers: authHeaders(token) });
  if (!res.ok) {
    throw new Error(`GitHub auth failed (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  return { login: data.login };
}

export async function pushFile(
  repoFullName: string,
  path: string,
  content: string,
  commitMessage: string,
  branch: string = "main"
) {
  const token = await getToken();

  let sha: string | undefined;
  const existing = await fetch(
    `${GITHUB_API}/repos/${repoFullName}/contents/${path}?ref=${branch}`,
    { headers: authHeaders(token) }
  );
  if (existing.ok) {
    const data = await existing.json();
    sha = data.sha;
  }

  const base64Content = base64Encode(content);

  const res = await fetch(`${GITHUB_API}/repos/${repoFullName}/contents/${path}`, {
    method: "PUT",
    headers: { ...authHeaders(token), "Content-Type": "application/json" },
    body: JSON.stringify({
      message: commitMessage,
      content: base64Content,
      branch,
      ...(sha ? { sha } : {}),
    }),
  });

  if (!res.ok) {
    throw new Error(`GitHub push failed (${res.status}): ${await res.text()}`);
  }
  return res.json();
}

export async function pushFiles(
  repoFullName: string,
  files: { path: string; content: string }[],
  commitMessage: string,
  branch: string = "main"
) {
  const results = [];
  for (const file of files) {
    const r = await pushFile(repoFullName, file.path, file.content, commitMessage, branch);
    results.push(r);
  }
  return results;
}

export async function triggerWorkflow(
  repoFullName: string,
  workflowFile: string,
  inputs: Record<string, string> = {},
  ref: string = "main"
) {
  const token = await getToken();
  const res = await fetch(
    `${GITHUB_API}/repos/${repoFullName}/actions/workflows/${workflowFile}/dispatches`,
    {
      method: "POST",
      headers: { ...authHeaders(token), "Content-Type": "application/json" },
      body: JSON.stringify({ ref, inputs }),
    }
  );
  if (!res.ok) {
    throw new Error(`Workflow trigger failed (${res.status}): ${await res.text()}`);
  }
  return true;
}

export async function listWorkflowRuns(repoFullName: string, workflowFile: string) {
  const token = await getToken();
  const res = await fetch(
    `${GITHUB_API}/repos/${repoFullName}/actions/workflows/${workflowFile}/runs?per_page=5`,
    { headers: authHeaders(token) }
  );
  if (!res.ok) {
    throw new Error(`Fetching runs failed (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  return (data.workflow_runs || []).map((r: any) => ({
    id: r.id,
    status: r.status,
    conclusion: r.conclusion,
    createdAt: r.created_at,
    htmlUrl: r.html_url,
  }));
}

export async function createRepo(name: string, isPrivate: boolean = true) {
  const token = await getToken();
  const res = await fetch(`${GITHUB_API}/user/repos`, {
    method: "POST",
    headers: { ...authHeaders(token), "Content-Type": "application/json" },
    body: JSON.stringify({ name, private: isPrivate, auto_init: true }),
  });
  if (!res.ok) {
    throw new Error(`Repo creation failed (${res.status}): ${await res.text()}`);
  }
  return res.json();
}

function base64Encode(str: string): string {
  const utf8 = unescape(encodeURIComponent(str));
  let output = "";
  if (typeof btoa === "function") return btoa(utf8);
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
  let i = 0;
  while (i < utf8.length) {
    const a = utf8.charCodeAt(i++);
    const b = utf8.charCodeAt(i++);
    const c = utf8.charCodeAt(i++);
    const e1 = a >> 2;
    const e2 = ((a & 3) << 4) | (isNaN(b) ? 0 : b >> 4);
    const e3 = isNaN(b) ? 64 : (((b & 15) << 2) | (isNaN(c) ? 0 : c >> 6));
    const e4 = isNaN(c) ? 64 : c & 63;
    output += chars[e1] + chars[e2] + chars[e3] + chars[e4];
  }
  return output;
      }
export async function getFileText(
  repoFullName: string,
  path: string,
  branch: string = "main"
): Promise<string | null> {
  const token = await getToken();
  const res = await fetch(
    `${GITHUB_API}/repos/${repoFullName}/contents/${path}?ref=${branch}&t=${Date.now()}`,
    { headers: { ...authHeaders(token), Accept: "application/vnd.github.raw+json" } }
  );
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Read failed (${res.status}): ${await res.text()}`);
  return res.text();
}

export async function listDir(
  repoFullName: string,
  path: string,
  branch: string = "main"
): Promise<string[]> {
  const token = await getToken();
  const res = await fetch(
    `${GITHUB_API}/repos/${repoFullName}/contents/${path}?ref=${branch}&t=${Date.now()}`,
    { headers: authHeaders(token) }
  );
  if (res.status === 404) return [];
  if (!res.ok) throw new Error(`List failed (${res.status}): ${await res.text()}`);
  const data = await res.json();
  return Array.isArray(data)
    ? data.filter((x: any) => x.type === "dir").map((x: any) => x.name)
    : [];
}

export async function latestRunId(repoFullName: string, workflowFile: string): Promise<number> {
  try {
    const runs = await listWorkflowRuns(repoFullName, workflowFile);
    return runs.length ? Math.max(...runs.map((r: any) => r.id)) : 0;
  } catch {
    return 0;
  }
}

export async function getFailureLog(repoFullName: string, runId: number): Promise<string> {
  try {
    const token = await getToken();
    const jr = await fetch(`${GITHUB_API}/repos/${repoFullName}/actions/runs/${runId}/jobs`, {
      headers: authHeaders(token),
    });
    if (!jr.ok) return "";
    const jobs = (await jr.json()).jobs || [];
    const job = jobs.find((j: any) => j.conclusion === "failure") || jobs[0];
    if (!job) return "";
    const lr = await fetch(`${GITHUB_API}/repos/${repoFullName}/actions/jobs/${job.id}/logs`, {
      headers: authHeaders(token),
    });
    if (!lr.ok) return "";
    return (await lr.text()).split("\n").slice(-12).join("\n");
  } catch {
    return "";
  }
}
