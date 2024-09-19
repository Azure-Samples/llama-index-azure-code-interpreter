import dotenv from "dotenv";
dotenv.config();

import {
  DefaultAzureCredential,
  getBearerTokenProvider,
} from "@azure/identity";
import got from "got";
import { BaseTool, ToolMetadata } from "llamaindex";
import crypto from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const uuidv4 = () => crypto.randomUUID();

export type InterpreterParameter = {
  code: string;
};
export type InterpreterToolOutput = {
  result: string;
  stdout: string;
  stderr: string;
};

export type AzureCodeInterpreterToolParams = {
  code?: string;
  metadata?: ToolMetadata;
  poolManagementEndpoint?: string;
  sessionId?: string;
  azureADTokenProvider?: () => Promise<string>;
};

let userAgent = "";
async function getuserAgentSuffix(): Promise<string> {
  try {
    //@ts-ignore
    const __filename = fileURLToPath(import.meta.url);
    const __dirname = dirname(__filename);

    if (!userAgent) {
      const data = await readFile(
        join(__dirname, "..", "package.json"),
        "utf8",
      );
      const json = await JSON.parse(data);
      userAgent = `${json.name}/${json.version}`;
    }
  } catch (e) {
    userAgent = `llamaIndex-azure-dynamic-sessions`;
  }
  return `${userAgent} (Language=TypeScript; node.js/${process.version}; ${process.platform}; ${process.arch})`;
}

function getAzureADTokenProvider() {
  return getBearerTokenProvider(
    new DefaultAzureCredential(),
    "https://dynamicsessions.io/.default",
  );
}

const DEFAULT_META_DATA: ToolMetadata = {
  name: "azure_dynamic_sessions_nodejs_interpreter",
  description:
    "A Node.js shell. Use this to execute Node.js and JavaScript commands " +
    "when you need to perform calculations or computations. " +
    "Input should be a valid JavaScript command. " +
    "Returns the result, stdout, and stderr. ",
  parameters: {
    type: "object",
    properties: {
      code: {
        type: "string",
        description: "The JavaScript code to execute",
      },
    },
    required: ["code"],
  },
};

export class AzureCodeInterpreterToolSpec
  implements BaseTool<AzureCodeInterpreterToolParams>
{
  metadata: ToolMetadata;
  sessionId: string;
  poolManagementEndpoint: string;
  private azureADTokenProvider: () => Promise<string>;

  constructor(params?: AzureCodeInterpreterToolParams) {
    this.metadata = params?.metadata || DEFAULT_META_DATA;
    this.sessionId = params?.sessionId || uuidv4();
    this.poolManagementEndpoint =
      params?.poolManagementEndpoint ||
      (process.env.AZURE_CONTAINER_APP_SESSION_POOL_MANAGEMENT_ENDPOINT ?? "");
    this.azureADTokenProvider =
      params?.azureADTokenProvider ?? getAzureADTokenProvider();
  }

  async call({
    code,
  }: Pick<
    AzureCodeInterpreterToolParams,
    "code"
  >): Promise<InterpreterToolOutput> {
    console.log(`Running Node.js code in session: ${this.sessionId}`);

    const token = await this.azureADTokenProvider();
    const apiUrl = `${this.poolManagementEndpoint}/code/execute?identifier=${this.sessionId}`;
    const headers = {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      "User-Agent": await getuserAgentSuffix(),
    };
    const body = {
      properties: {
        codeInputType: "inline",
        executionType: "synchronous",
        timeout: 60,
        enableEgress: true,
        code: code || "console.log('no code provided')",
      },
    };

    console.log(`Sending request to: ${apiUrl}`);
    console.log(`Request headers: ${JSON.stringify(headers)}`);
    console.log(`Request body: ${JSON.stringify(body)}`);

    try {
      return await got
        .post(apiUrl, {
          method: "POST",
          headers,
          body: JSON.stringify(body),
        })
        .json();
    } catch (error: any) {
      console.error(`Error: Failed to execute Node.js code. ${error}`);
      return {
        result: error.message,
        stdout: error.message,
        stderr: "Error: Failed to execute Node.js code. " + error,
      };
    }
  }
}
