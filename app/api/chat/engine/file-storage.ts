import dotenv from "dotenv";
dotenv.config();

import { DefaultAzureCredential } from "@azure/identity";
import { BlobServiceClient, BlockBlobUploadHeaders } from "@azure/storage-blob";
import { getEnv } from "@llamaindex/env";

export async function uploadFileToAzureStorage(
  fileName: string,
  fileContentsAsBuffer: Buffer,
): Promise<string> {
  const accountName = getEnv("AZURE_STORAGE_ACCOUNT") ?? "";

  if (!accountName) {
    throw new Error("AZURE_STORAGE_ACCOUNT must be defined.");
  }

  const blobServiceClient = new BlobServiceClient(
    `https://${accountName}.blob.core.windows.net`,
    new DefaultAzureCredential(),
  );

  const containerName = getEnv("AZURE_STORAGE_CONTAINER") || "files";

  const containerClient = blobServiceClient.getContainerClient(containerName);
  const blobClient = containerClient.getBlockBlobClient(fileName);

  // Get file url - available before contents are uploaded
  console.log(`blob.url: ${blobServiceClient.url}`);

  // Upload file contents
  const result: BlockBlobUploadHeaders =
    await blobClient.uploadData(fileContentsAsBuffer);

  if (result.errorCode) throw Error(result.errorCode);

  // Get results
  return `${blobServiceClient.url}${containerName}/${fileName}`;
}
