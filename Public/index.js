function installiOSWithId(id) {
    const host = window.location.host;
    const url = `itms-services://?action=download-manifest&url=https://${host}/install/${id}/install.plist`;
    window.location.href = url;
}

function deletePkg(uuid) {
    if (confirm("Are your sure to delete this PKG?")) {
        fetch(`/api/${uuid}`,
            { method: "DELETE" })
            .then(function (response) {
                setTimeout(function () {
                    location.reload();
                    console.log(response.status);
                }, 500);
            }).catch((error) => {
                console.log(error);
            })
    }
}

function deletePkgWithoutConfirm(uuid) {
    fetch(`/api/${uuid}`,
          { method: "DELETE" })
    .then(function (response) {
        setTimeout(function () {
            location.reload();
            console.log(response.status);
        }, 500);
    }).catch((error) => {
        console.log(error);
    })
}
