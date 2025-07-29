import { LightningElement, api } from "lwc";
// Import static resource
import myLogo from "@salesforce/resourceUrl/myCompanyLogo";

export default class CustomSpinner extends LightningElement {
  /**
   * Public property to control spinner visibility.
   * When a parent component sets this to true, the spinner appears.
   * Default is false.
   */
  @api isLoading = false;

  /**
   * Expose the static resource URL to the template
   */
  logoUrl = myLogo;
}
