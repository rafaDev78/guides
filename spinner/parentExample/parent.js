import { LightningElement, track } from "lwc";

export default class ParentComponentExample extends LightningElement {
  @track showSpinner = false;

  handleProcessClick() {
    // Set spinner to true to show it
    this.showSpinner = true;

    // --- In a real component, you would make your Apex call here ---
    // e.g., callApexMethod()
    //          .then(result => { ... })
    //          .catch(error => { ... })
    //          .finally(() => { this.showSpinner = false; });
    // -------------------------------------------------------------

    // We simulate a server call with a 3-second delay
    setTimeout(() => {
      // After the process is complete, hide the spinner
      this.showSpinner = false;
    }, 5000);
  }
}
