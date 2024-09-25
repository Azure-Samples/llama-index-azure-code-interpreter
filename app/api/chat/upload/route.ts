import { NextRequest, NextResponse } from "next/server";
import { getDataSource } from "../engine";
import { initSettings } from "../engine/settings";
import { uploadDocument } from "../llamaindex/documents/upload";
import { AzureDynamicSessionTool } from "../engine/tools/__azure-code-interpreter";

initSettings();

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    const {
      filename,
      base64,
      params,
    }: { filename: string; base64: string; params?: any } =
      await request.json();
    if (!base64 || !filename) {
      return NextResponse.json(
        { error: "base64 and filename is required in the request body" },
        { status: 400 },
      );
    }

    console.log("[Upload API] Uploading document", {params});

    const index = await getDataSource(params);
    if (index) {
      // throw new Error(
      //   `StorageContext is empty - call 'npm run generate' to generate the storage first`,
      // );
      return NextResponse.json(await uploadDocument(index, filename, base64));
    }
    else {
      return NextResponse.json(new AzureDynamicSessionTool().uploadFile({
        remoteFilename: filename,
        base64,
      }));
    }
  } catch (error) {
    console.error("[Upload API]", error);
    return NextResponse.json(
      { error: (error as Error).message },
      { status: 500 },
    );
  }
}
