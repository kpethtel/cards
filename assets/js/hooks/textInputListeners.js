const TextInputListeners = {
  mounted() {
    this.el.addEventListener("keyup", (event) => {
      if (event.key === "Escape" || event.key === "Esc") {
        toggleInputMode();
      } else if (event.key === "Enter") {
        var textInput = document.getElementById("text-input");
        textInput.value = '';
      }
    });
    this.el.addEventListener("keydown", (event) => {
      if (event.metaKey && event.code === "ArrowLeft") {
        this.pushEvent("change_image", {"direction": "previous"})
      } else if (event.metaKey && event.code === "ArrowRight") {
        this.pushEvent("change_image", {"direction": "next"})
      } else if (event.ctrlKey && event.code === "Enter") {
        this.pushEvent("select_answer")
      }
    });
    document.getElementById('input-type-toggle').addEventListener('click', toggleInputMode);
  }
}

const toggleInputMode = () => {
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

export default TextInputListeners;