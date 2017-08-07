document.body.classList.add('js');

function action(url, data) {
    swal({
        title: "Action on file",
        text: "...",
        type: "info",
        allowOutsideClick: false
    });
    swal.showLoading();
    XHR.get(url, data, function (result) {
        console.log("Document sent!");
        displayResponse(result.response);
    });
}

function askEmail(callback) {
    var defaultEmail = null;
    if (typeof (Storage) !== "undefined") {
        defaultEmail = localStorage.getItem("usbleach_email");
    }
    swal({
        title: "Receive file by mail",
        text: "What is your email address?",
        type: "question",
        input: 'email',
        allowOutsideClick: true,
        animation: "slide-from-top",
        inputPlaceholder: "my.name@company.tld",
        inputValue: defaultEmail,
        showLoaderOnConfirm: true
    }).then(function (inputValue) {
        if (inputValue === false || inputValue === "")
            return false;
        localStorage.setItem("usbleach_email", inputValue);
        swal({
            title: "Sending you your file",
            text: "...",
            type: "info",
            allowOutsideClick: false
        });
        swal.showLoading();
        callback(inputValue);
    });
}

function download(link) {
    var anchor = document.createElement('a');
    anchor.href = link;
    anchor.setAttribute("download", "");
    document.body.appendChild(anchor);
    anchor.click();
}

var myChristmasTreeElement = document.querySelector("ul#myChristmasTree");
if (myChristmasTreeElement) {
    XHR.poll(2, '/cgi-bin/luci/admin/usbleach/overview?ajax&', null, function (x) {
        var data = JSON.parse(x.response);
        myChristmasTreeElement.innerHTML = data.usb;
    });
}

var mkdirInput = document.querySelector("input#mkdir");
mkdirInput.addEventListener("click", function (e) {
    e.preventDefault();
    swal({
        title: 'Directory name',
        input: 'text',
        showCancelButton: true
    }).then(function (result) {
        if (!result)
            return;

        var formData = new FormData();
        formData.append("dir", result);
        var request = new XMLHttpRequest();
        request.open("POST", mkdirEndpoint);
        request.addEventListener("load", function () {
            document.location.reload();
        });
        request.send(formData);
    });
});

var upfileInput = document.querySelector("input#upfile");
upfileInput.addEventListener("click", function (e) {
    e.preventDefault();
    swal({
        title: 'Select file',
        input: 'file'
    }).then(function (file) {
        swal({
            title: "Uploading file",
            text: "...",
            type: "info",
            allowOutsideClick: false
        });
        swal.showLoading();
        var formData = new FormData();
        formData.append("file", file);
        var request = new XMLHttpRequest();
        request.open("POST", upfileEndpoint);
        request.addEventListener("load", function () {
            swal.close();
            document.location.reload();
        });
        request.send(formData);
    })
});