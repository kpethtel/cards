const InputTypeToggleListener = {
  mounted() {
    this.el.addEventListener("keyup", (event) => {
      console.log(event)
      if (event.key === "Escape" || event.key === "Esc") {
        var textInputArea = document.getElementById("text-input-area");
        var submitAction = textInputArea.getAttribute("phx-submit");

        if (submitAction === "submit_chat_message") {
          textInputArea.removeAttribute("phx-submit");
          textInputArea.setAttribute("phx-submit", "submit_search_query");
          document.getElementById("input-type-toggle").innerText = "Search";
        } else if (submitAction === "submit_search_query") {
          textInputArea.removeAttribute("phx-submit");
          textInputArea.setAttribute("phx-submit", "submit_chat_message");
          document.getElementById("input-type-toggle").innerText = "Chat";
        }
      }
    })
  }
}

export default InputTypeToggleListener;