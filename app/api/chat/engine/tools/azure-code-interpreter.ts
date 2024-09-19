import { ToolMetadata } from "llamaindex";
import { AzureCodeInterpreterToolParams, AzureCodeInterpreterToolSpec as AzureCodeInterpreterTool} from "./azure-code-interpreter__patch";

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

export class AzureDynamicSessionToolSpec extends AzureCodeInterpreterTool {
  constructor(config: AzureCodeInterpreterToolParams) {
    config.metadata = DEFAULT_META_DATA;
    super(config);
  }
}