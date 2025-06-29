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
