import { BaseToolWithCall } from "llamaindex";
import { ImgGeneratorTool, ImgGeneratorToolParams } from "./img-gen";
import { OpenAPIActionTool } from "./openapi-action";
import { AzureCodeInterpreterToolSpec } from "./azure-code-interpreter__patch";

type ToolCreator = (config: unknown) => Promise<BaseToolWithCall[]>;

export async function createTools(toolConfig: {
  local: Record<string, unknown>;
  llamahub: any;
}): Promise<BaseToolWithCall[]> {
  // add local tools from the 'tools' folder (if configured)
  return await createLocalTools(toolConfig.local);
}

const toolFactory: Record<string, ToolCreator> = {
  interpreter: async (config: unknown) => {
    return [new AzureCodeInterpreterToolSpec(config as any)];
  },
  "openapi_action.OpenAPIActionToolSpec": async (config: unknown) => {
    const { openapi_uri, domain_headers } = config as {
      openapi_uri: string;
      domain_headers: Record<string, Record<string, string>>;
    };
    const openAPIActionTool = new OpenAPIActionTool(
      openapi_uri,
      domain_headers,
    );
    return await openAPIActionTool.toToolFunctions();
  },
  img_gen: async (config: unknown) => {
    return [new ImgGeneratorTool(config as ImgGeneratorToolParams)];
  },
};

async function createLocalTools(
  localConfig: Record<string, unknown>,
): Promise<BaseToolWithCall[]> {
  const tools: BaseToolWithCall[] = [];

  for (const [key, toolConfig] of Object.entries(localConfig)) {
    if (key in toolFactory) {
      const newTools = await toolFactory[key](toolConfig);
      tools.push(...newTools);
    }
  }

  return tools;
}
