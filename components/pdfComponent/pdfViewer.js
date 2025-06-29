  import { LightningElement, api } from "lwc";

export default class PdfViewer extends LightningElement {
  // public properties to be used by a parent component
  @api fileId;
  @api pageNumber;

  // Dispatch event to be received by parent component when close button is clicked.
  handleCloseClick() {
    this.dispatchEvent(new CustomEvent("closeviewer"));
  }

  get pdfUrl() {
    if (this.fileId) {
      // This base url is based on ContentDocument system. For attachment object this needs to change.
      let baseUrl = `/sfc/servlet.shepherd/document/download/${this.fileId}`;
      // if is based in attachments:
      //let baseUrl = `/servlet/servlet.FileDownload?file=${this.attachmentId}`;

      let fragment = "";
      const params = [];

      // Adobe viewer params. This are used by the request made by salesforce to the browser to render the pdf.
      params.push("view=Fit");
      params.push("navpanes=0");

      if (this.pageNumber > 0) {
        params.push(`page=${this.pageNumber}`);
      }

      if (params.length > 0) {
        fragment = "#" + params.join("&");
      }
      return baseUrl + fragment;
    }
    return "";
  }
}
