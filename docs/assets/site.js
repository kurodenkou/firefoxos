// Firox Linux website: copy buttons on code blocks, and a click-to-enlarge
// view for screenshots. The pages work without it.
(function () {
    document.querySelectorAll(".code").forEach(function (box) {
        var pre = box.querySelector("pre");
        if (!pre || !navigator.clipboard) return;
        var btn = document.createElement("button");
        btn.type = "button";
        btn.textContent = "Copy";
        btn.addEventListener("click", function () {
            navigator.clipboard.writeText(pre.innerText.trim()).then(function () {
                btn.textContent = "Copied";
                setTimeout(function () { btn.textContent = "Copy"; }, 1500);
            });
        });
        box.appendChild(btn);
    });

    var box = document.createElement("div");
    box.className = "lightbox";
    box.setAttribute("role", "dialog");
    box.setAttribute("aria-label", "Screenshot");
    var big = document.createElement("img");
    box.appendChild(big);
    document.body.appendChild(box);
    function close() { box.classList.remove("open"); }
    box.addEventListener("click", close);
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") close(); });
    document.querySelectorAll("figure img, .hero .shot").forEach(function (img) {
        img.addEventListener("click", function () {
            big.src = img.currentSrc || img.src;
            big.alt = img.alt;
            box.classList.add("open");
        });
    });
})();
