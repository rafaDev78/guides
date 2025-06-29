The child dispatch an event this way:

```js
 // Dispatch an event named 'closeviewer'
  handleCloseClick() {
    this.dispatchEvent(new CustomEvent("closeviewer"));
  }

```

the event is configured in the parent component html with a property as in this example:
In this case the property is called oncloseviewer referencing the event above.

```html
  <c-pdf-viewer
          file-id={selectedFileId}
          page-number={selectedPageNumber}
          oncloseviewer={handleCloseViewer}
        >
        </c-pdf-viewer>
```

The method handleCloseViewer receives the event and execute needed actions.


Also in the parent, to show the child component in its own card:

```html
 <div class="slds-m-top_medium">
      <lightning-card title="PDF Viewer">
        <c-pdf-viewer
          file-id={selectedFileId}
          page-number={selectedPageNumber}
          oncloseviewer={handleCloseViewer}
        >
        </c-pdf-viewer>
      </lightning-card>
    </div>
```

The button that opens the viewer needs to pass the details to the child component using the api decorator in the child component, with a syntax like this:

```html
    <lightning-button
                    label="View Page 2"
                    data-page="2"
                    data-fileid={fileToViewId}
                    onclick={handleViewPageClick}
                    class="slds-m-left_small"
                  >
                  </lightning-button>
```

Handler in the Parent component to set properties to be passed can look like this:
```js
  //Handler to render the PDF viewer
  handleViewPageClick(event) {
    const page = event.target.dataset.page;
    const fileId = event.target.dataset.fileid;

    // set properties for child component:
    this.selectedFileId = fileId;
    this.selectedPageNumber = page;

    // Set boolean to true for conditional rendering:
    this.showPdfViewer = true;
  }
```
