var init = function() {

  var empty_object = function(obj) {
    return Object.keys(obj).length === 0 && obj.constructor === Object
  }

  var get_metadata = function(url, callback) {
    console.log("getting metadata for:", url)

    var xhr = new XMLHttpRequest()
    xhr.open("GET", url)
    xhr.setRequestHeader("Accept", "application/metadata+json")
    xhr.onload = function() { callback(JSON.parse(xhr.responseText)) }
    xhr.send()
  }

  function keyboard_handler(event) {
    if (event.keyCode == 38 && event.altKey) {
      document.querySelector("a.up").click()
      event.preventDefault()
    }
  }
  document.addEventListener("keydown", keyboard_handler)

  document.querySelectorAll(".icon").forEach(function(td) {
    var e = td.children[0]

    e.onclick = function() {

      var link_td = td.parentNode.children[1]
      var existing_metadata = link_td.querySelector(".metadata")

      if (existing_metadata) {
        existing_metadata.remove()
      } else {
        var url = link_td.querySelector("a")["href"]

        get_metadata(url, function(json) {

          var div = document.createElement("div")
          div.className = "metadata"

          if (empty_object(json)) {
            div.innerHTML = "<b>No metadata</b>"
          } else {
            html = "<dl>\n"

            for (var key in json) {
              html += "<dt>"+key.replace(/^user\.(dublincore\.)?/, '')+"</dt>\n"
              var val = json[key]
              console.log(key)

              if (key.match(/\.url$/)) {
                val = '<a href="'+val+'">'+val+'</a>'
              } else {
                val = "<pre>"+val+"</pre>"
              }
              html += "<dd>"+val+"</dd>\n"
            }
            html += "</dl>\n"

            div.innerHTML = html
          }

          link_td.appendChild(div)
        })
      }
    }
  })

  console.log("loaded!")
}

window.addEventListener("DOMContentLoaded", init, false)
