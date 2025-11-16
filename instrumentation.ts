declare global {
  var secrets: {
    apiKey?: string;
  };
}

export async function register() {
  global.secrets = {};

  const org = process.env.HCP_ORG;
  const project = process.env.HCP_PROJECT;
  const secretName = "Demo";

  if (!org) {
    global.secrets.apiKey = "Demo: You have not loaded your secrets";
    return;
  }

  try {
    const res = await fetch(
      `https://api.cloud.hashicorp.com/secrets/2023-06-13/organizations/${org}/projects/${project}/apps/${secretName}/open`,
      {
        headers: {
          Authorization: `Bearer ${process.env.HCP_API_KEY}`,
        },
      },
    );

    if (!res.ok) {
      global.secrets.apiKey = `Demo: Failed to fetch secrets (${res.status})`;
      return;
    }

    const data = await res.json();
    const secrets = data.secrets;

    if (
      !secrets ||
      !Array.isArray(secrets) ||
      secrets.length === 0 ||
      !secrets[0]?.version?.value
    ) {
      global.secrets.apiKey = "Demo: Invalid secrets response";
      return;
    }

    global.secrets.apiKey = secrets[0].version.value;
    console.log("Secrets loaded!");
  } catch (error) {
    global.secrets.apiKey = `Demo: Error loading secrets: ${
      error instanceof Error ? error.message : String(error)
    }`;
  }
}
