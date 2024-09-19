import { BaseToolWithCall } from "llamaindex";
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
  }
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
