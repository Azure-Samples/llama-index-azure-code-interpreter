import { VectorStoreIndex } from "llamaindex";
import { storeAndParseFile } from "./helper";
import { runPipeline } from "./pipeline";

export async function uploadDocument(
  index: VectorStoreIndex,
  filename: string,
  raw: string,
): Promise<string[]> {
  const [header, content] = raw.split(",");
  const mimeType = header.replace("data:", "").replace(";base64", "");
  const fileBuffer = Buffer.from(content, "base64");

  // run the pipeline for other vector store indexes
  const documents = await storeAndParseFile(filename, fileBuffer, mimeType);
  return runPipeline(index, documents);
}
