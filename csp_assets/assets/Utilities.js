(function () {
	'use strict';

	// ── Tool tab switching (extensible for future tools) ──────────────────────
	document.querySelectorAll('.toolTab').forEach(function (btn) {
		btn.addEventListener('click', function () {
			document.querySelectorAll('.toolTab').forEach(function (b) { b.classList.remove('active'); });
			document.querySelectorAll('.toolPanel').forEach(function (p) { p.style.display = 'none'; });
			btn.classList.add('active');
			var panel = document.getElementById('tool-' + btn.dataset.tool);
			if (panel) panel.style.display = '';
		});
	});

	// ── Base64 Decoder ────────────────────────────────────────────────────────

	var inputEl      = document.getElementById('InputArea');
	var decodeBtn    = document.getElementById('DecodeBtn');
	var clearBtn     = document.getElementById('ClearBtn');
	var copyBtn      = document.getElementById('CopyBtn');
	var downloadLink = document.getElementById('DownloadLink');
	var badge        = document.getElementById('DetectedType');
	var outText      = document.getElementById('OutputText');
	var outImage     = document.getElementById('OutputImage');
	var outPdf       = document.getElementById('OutputPdf');
	var outEmpty     = document.getElementById('OutputEmpty');

	var _lastBlobUrl = null;
	var _decodeTimer = null;

	// Auto-decode on paste (debounced)
	inputEl.addEventListener('paste', function () {
		clearTimeout(_decodeTimer);
		_decodeTimer = setTimeout(decode, 120);
	});

	decodeBtn.addEventListener('click', decode);

	clearBtn.addEventListener('click', function () {
		inputEl.value = '';
		showEmpty();
	});

	copyBtn.addEventListener('click', function () {
		var text = outText.textContent;
		if (!text) return;
		navigator.clipboard.writeText(text).catch(function () {
			var ta = document.createElement('textarea');
			ta.value = text;
			document.body.appendChild(ta);
			ta.select();
			document.execCommand('copy');
			document.body.removeChild(ta);
		});
		copyBtn.textContent = 'Copied!';
		setTimeout(function () { copyBtn.textContent = 'Copy'; }, 1500);
	});

	function decode() {
		var raw = inputEl.value.trim();
		if (!raw) { showEmpty(); return; }

		// Strip data URI prefix if present: data:...;base64,<data>
		var dataUriMatch = raw.match(/^data:([^;]+);base64,(.+)$/s);
		var mimeHint = null;
		var b64;
		if (dataUriMatch) {
			mimeHint = dataUriMatch[1].toLowerCase();
			b64 = dataUriMatch[2].trim();
		} else {
			b64 = raw.replace(/\s+/g, '');
		}

		// Validate base64 charset
		if (!/^[A-Za-z0-9+/]*={0,2}$/.test(b64)) {
			showError('Not valid base64 — unexpected characters');
			return;
		}

		var bytes;
		try {
			var bin = atob(b64);
			bytes = new Uint8Array(bin.length);
			for (var i = 0; i < bin.length; i++) { bytes[i] = bin.charCodeAt(i); }
		} catch (e) {
			showError('Decode failed: ' + e.message);
			return;
		}

		var mime = mimeHint || sniffMime(bytes);
		revokeLast();

		if (mime && mime.startsWith('image/')) {
			var blob = new Blob([bytes], { type: mime });
			_lastBlobUrl = URL.createObjectURL(blob);
			showImage(_lastBlobUrl, mime, blob);
		} else if (mime === 'application/pdf') {
			var blob = new Blob([bytes], { type: 'application/pdf' });
			_lastBlobUrl = URL.createObjectURL(blob);
			showPdf(_lastBlobUrl, blob);
		} else {
			// Try UTF-8 text decode
			var text;
			try {
				text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
			} catch (e) {
				// Fall back to latin-1
				text = new TextDecoder('latin1').decode(bytes);
			}
			showText(text);
		}
	}

	function sniffMime(bytes) {
		// Magic byte detection
		if (bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) return 'image/jpeg';
		if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) return 'image/png';
		if (bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) return 'image/gif';
		if (bytes[0] === 0x42 && bytes[1] === 0x4D) return 'image/bmp';
		if (bytes[0] === 0x25 && bytes[1] === 0x50 && bytes[2] === 0x44 && bytes[3] === 0x46) return 'application/pdf';
		// RIFF/WEBP
		if (bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
		    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) return 'image/webp';
		return null;
	}

	function showText(text) {
		hideAll();
		outText.textContent = text;
		outText.classList.remove('is-hidden');
		copyBtn.classList.remove('is-hidden');
		setBadge('TEXT', 'is-text');
		downloadLink.classList.add('is-hidden');
	}

	function showImage(url, mime, blob) {
		hideAll();
		outImage.src = url;
		outImage.classList.remove('is-hidden');
		copyBtn.classList.add('is-hidden');
		setBadge(mime.split('/')[1].toUpperCase(), 'is-image');
		setDownload(blob, 'image.' + (mime.split('/')[1] || 'bin'));
	}

	function showPdf(url, blob) {
		hideAll();
		outPdf.src = url;
		outPdf.classList.remove('is-hidden');
		copyBtn.classList.add('is-hidden');
		setBadge('PDF', 'is-pdf');
		setDownload(blob, 'document.pdf');
	}

	function showError(msg) {
		hideAll();
		outText.textContent = msg;
		outText.classList.remove('is-hidden');
		copyBtn.classList.add('is-hidden');
		setBadge('Error', 'is-error');
		downloadLink.classList.add('is-hidden');
	}

	function showEmpty() {
		hideAll();
		outEmpty.classList.remove('is-hidden');
		setBadge('', '');
		downloadLink.classList.add('is-hidden');
		copyBtn.classList.remove('is-hidden');
	}

	function hideAll() {
		outText.classList.add('is-hidden');
		outImage.classList.add('is-hidden');
		outPdf.classList.add('is-hidden');
		outEmpty.classList.add('is-hidden');
	}

	function setBadge(label, cls) {
		badge.textContent = label;
		badge.className = 'detectedBadge' + (cls ? ' ' + cls : '');
	}

	function setDownload(blob, filename) {
		revokeLast();
		_lastBlobUrl = URL.createObjectURL(blob);
		downloadLink.href = _lastBlobUrl;
		downloadLink.download = filename;
		downloadLink.textContent = '\u2193 ' + filename;
		downloadLink.classList.remove('is-hidden');
	}

	function revokeLast() {
		if (_lastBlobUrl) { URL.revokeObjectURL(_lastBlobUrl); _lastBlobUrl = null; }
	}

	// Initialise
	showEmpty();

}());
