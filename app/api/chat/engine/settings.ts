import {
  DefaultAzureCredential,
  getBearerTokenProvider,
} from "@azure/identity";
import { OpenAI, OpenAIEmbedding, Settings } from "llamaindex";

const CHUNK_SIZE = 512;
const CHUNK_OVERLAP = 20;
const AZURE_AD_SCOPE = "https://cognitiveservices.azure.com/.default";

export const initSettings = async () => {
  initAzureOpenAI();

  Settings.chunkSize = CHUNK_SIZE;
  Settings.chunkOverlap = CHUNK_OVERLAP;
};

function initAzureOpenAI() {
  const credential = new DefaultAzureCredential();
  const azureADTokenProvider = getBearerTokenProvider(
    credential,
    AZURE_AD_SCOPE,
  );

  const azure = {
    apiVersion: "2023-03-15-preview",
    azureADTokenProvider,
    deployment: process.env.AZURE_OPENAI_DEPLOYMENT ?? "gpt-4o-mini",
  };

  Settings.llm = new OpenAI({azure});
  Settings.embedModel = new OpenAIEmbedding({
    azure,
    model: process.env.EMBEDDING_MODEL,
    dimensions: process.env.EMBEDDING_DIM
      ? parseInt(process.env.EMBEDDING_DIM)
      : undefined,
  });
}
