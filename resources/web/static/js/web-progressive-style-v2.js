(function () {
    'use strict';

    if (window.__elementumWebProgressiveStyleV2) {
        return;
    }
    window.__elementumWebProgressiveStyleV2 = true;

    function cleanKodiMarkup(value) {
        return String(value || '')
            .replace(/\[(?:\/?B|\/?I|\/COLOR|COLOR(?:\s+|=)[^\]]+)\]/gi, '')
            .replace(/\[CR\]/gi, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    function normalizeQuality(value) {
        return String(value || '').toLowerCase();
    }

    function parseSummary(value) {
        var summary = cleanKodiMarkup(value);
        var parsed = {
            quality: '',
            seeds: '',
            peers: '',
            size: '',
            releaseType: '',
            providers: [],
            fallback: summary
        };

        var match = summary.match(/^(?:(4K|2160p|2K|1080p|720p|480p|240p)\s+)?\(\s*(\d+)\s*\/\s*(\d+)\s*\)\s*(?:\[([^\]]+)\])?\s*(.*)$/i);
        if (!match) {
            parsed.releaseType = summary;
            return parsed;
        }

        parsed.quality = match[1] || '';
        parsed.seeds = match[2] || '0';
        parsed.peers = match[3] || '0';
        parsed.size = match[4] || '';

        var tail = String(match[5] || '').trim();
        var parts = tail.split(/\s+-\s+/);
        parsed.releaseType = parts.shift() || '';

        if (parts.length) {
            parsed.providers = parts.join(' - ').split(',').map(function (item) {
                return item.trim();
            }).filter(function (item) {
                return item.length > 0;
            });
        }

        return parsed;
    }

    function addStyle() {
        if (document.getElementById('elementum-progressive-style-v2')) {
            return;
        }

        var style = document.createElement('style');
        style.id = 'elementum-progressive-style-v2';
        style.textContent = [
            '#elementum-progressive-overlay{background:rgba(3,7,18,.84)!important;backdrop-filter:blur(5px)!important;padding:20px!important}',
            '#elementum-progressive-modal{width:min(1180px,97vw)!important;max-height:94vh!important;background:linear-gradient(180deg,#161b22 0%,#11161d 100%)!important;border-radius:14px!important;box-shadow:0 24px 90px rgba(0,0,0,.72)!important}',
            '#elementum-progressive-head{padding:18px 20px!important;background:rgba(22,27,34,.97)!important}',
            '#elementum-progressive-title{font-size:19px!important;font-weight:750!important;color:#f0f6fc!important}',
            '#elementum-progressive-count{font-size:12px!important;font-weight:700!important;color:#c9d1d9!important;background:#21262d!important;border:1px solid #30363d!important;border-radius:999px!important;padding:6px 10px!important}',
            '#elementum-progressive-close{width:34px!important;height:34px!important;border-radius:8px!important;color:#8b949e!important;transition:.15s!important}',
            '#elementum-progressive-close:hover{background:#21262d!important;color:#f0f6fc!important}',
            '#elementum-progressive-status{min-height:42px!important;display:flex!important;align-items:center!important;padding:10px 20px!important;background:#0f141b!important;border-bottom-color:#252b33!important}',
            '#elementum-progressive-list{padding:12px!important;gap:9px!important;scrollbar-color:#3b434d #11161d;scrollbar-width:thin}',
            '#elementum-progressive-list::-webkit-scrollbar{width:10px}',
            '#elementum-progressive-list::-webkit-scrollbar-track{background:#11161d}',
            '#elementum-progressive-list::-webkit-scrollbar-thumb{background:#3b434d;border:2px solid #11161d;border-radius:999px}',
            '.elementum-progressive-item{position:relative!important;background:#1b2129!important;border:1px solid #30363d!important;border-radius:10px!important;padding:13px 15px 14px 17px!important;overflow:hidden!important;box-shadow:none!important;transition:background .14s,border-color .14s,transform .14s,box-shadow .14s!important}',
            '.elementum-progressive-item:before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:#6e7681}',
            '.elementum-progressive-item[data-quality="4k"]:before,.elementum-progressive-item[data-quality="2160p"]:before{background:#58a6ff}',
            '.elementum-progressive-item[data-quality="1080p"]:before{background:#a371f7}',
            '.elementum-progressive-item[data-quality="720p"]:before{background:#3fb950}',
            '.elementum-progressive-item:hover,.elementum-progressive-item:focus-visible{background:#222a34!important;border-color:#58a6ff!important;box-shadow:0 5px 22px rgba(0,0,0,.28)!important;transform:translateY(-1px)!important;outline:none!important}',
            '.elementum-progressive-v2-meta{display:flex;align-items:center;gap:7px;flex-wrap:wrap;margin-bottom:9px}',
            '.elementum-progressive-v2-spacer{flex:1;min-width:10px}',
            '.elementum-progressive-v2-badge{display:inline-flex;align-items:center;min-height:24px;padding:3px 8px;border-radius:6px;background:#252c35;border:1px solid #343c47;color:#c9d1d9;font-size:11px;font-weight:700;line-height:1;white-space:nowrap}',
            '.elementum-progressive-v2-quality{color:#fff;background:#30363d}',
            '.elementum-progressive-v2-quality[data-quality="4k"],.elementum-progressive-v2-quality[data-quality="2160p"]{background:#1f6feb;border-color:#388bfd}',
            '.elementum-progressive-v2-quality[data-quality="1080p"]{background:#6e40c9;border-color:#8957e5}',
            '.elementum-progressive-v2-quality[data-quality="720p"]{background:#238636;border-color:#2ea043}',
            '.elementum-progressive-v2-seeds{color:#7ee787;background:rgba(35,134,54,.18);border-color:rgba(46,160,67,.55)}',
            '.elementum-progressive-v2-peers{color:#d2a8ff;background:rgba(110,64,201,.16);border-color:rgba(137,87,229,.45)}',
            '.elementum-progressive-v2-size{color:#79c0ff;background:rgba(31,111,235,.14);border-color:rgba(56,139,253,.42)}',
            '.elementum-progressive-v2-provider{color:#f0f6fc;background:#30363d;border-color:#484f58}',
            '.elementum-progressive-v2-title{font-size:14px;font-weight:650;line-height:1.45;color:#e6edf3;word-break:break-word}',
            '@media(max-width:720px){#elementum-progressive-overlay{padding:0!important}#elementum-progressive-modal{width:100vw!important;max-height:100vh!important;height:100vh!important;border-radius:0!important}#elementum-progressive-head{padding:14px 13px!important}.elementum-progressive-item{padding:12px 11px 13px 14px!important}.elementum-progressive-v2-spacer{display:none}.elementum-progressive-v2-provider{order:20}#elementum-progressive-title{font-size:16px!important}}'
        ].join('');
        document.head.appendChild(style);
    }

    function badge(text, className, title) {
        var element = document.createElement('span');
        element.className = 'elementum-progressive-v2-badge ' + (className || '');
        element.textContent = text;
        if (title) {
            element.title = title;
        }
        return element;
    }

    function beautifyItem(button) {
        if (!button || button.getAttribute('data-elementum-style-v2') === '1') {
            return;
        }

        var main = button.querySelector('.elementum-progressive-main');
        var oldName = button.querySelector('.elementum-progressive-name');
        if (!main && !oldName) {
            return;
        }

        var parsed = parseSummary(main ? main.textContent : '');
        var title = cleanKodiMarkup(oldName ? oldName.textContent : parsed.fallback);
        var qualityKey = normalizeQuality(parsed.quality);

        button.setAttribute('data-elementum-style-v2', '1');
        button.setAttribute('data-quality', qualityKey);
        button.textContent = '';

        var meta = document.createElement('div');
        meta.className = 'elementum-progressive-v2-meta';

        if (parsed.quality) {
            var quality = badge(parsed.quality, 'elementum-progressive-v2-quality', 'Разрешение');
            quality.setAttribute('data-quality', qualityKey);
            meta.appendChild(quality);
        }
        if (parsed.seeds !== '') {
            meta.appendChild(badge('● ' + parsed.seeds + ' сидов', 'elementum-progressive-v2-seeds', 'Количество раздающих'));
        }
        if (parsed.peers !== '') {
            meta.appendChild(badge('○ ' + parsed.peers + ' пиров', 'elementum-progressive-v2-peers', 'Количество скачивающих'));
        }
        if (parsed.size) {
            meta.appendChild(badge(parsed.size, 'elementum-progressive-v2-size', 'Размер'));
        }
        if (parsed.releaseType) {
            meta.appendChild(badge(parsed.releaseType, '', 'Тип релиза'));
        }

        var spacer = document.createElement('span');
        spacer.className = 'elementum-progressive-v2-spacer';
        meta.appendChild(spacer);

        parsed.providers.forEach(function (provider) {
            meta.appendChild(badge(provider, 'elementum-progressive-v2-provider', 'Провайдер'));
        });

        var titleNode = document.createElement('div');
        titleNode.className = 'elementum-progressive-v2-title';
        titleNode.textContent = title || parsed.fallback;

        button.appendChild(meta);
        button.appendChild(titleNode);
    }

    function repairStatus() {
        var status = document.getElementById('elementum-progressive-status');
        var list = document.getElementById('elementum-progressive-list');
        if (!status || !list) {
            return;
        }

        var count = list.querySelectorAll('.elementum-progressive-item').length;
        var text = String(status.textContent || '');
        if (count > 0 && /Превышено время ожидания результатов/i.test(text)) {
            status.textContent = 'Результаты готовы. Выберите подходящий торрент.';
        }
    }

    function beautifyOverlay() {
        addStyle();
        var list = document.getElementById('elementum-progressive-list');
        if (!list) {
            return;
        }

        Array.prototype.forEach.call(
            list.querySelectorAll('.elementum-progressive-item'),
            beautifyItem
        );
        repairStatus();
    }

    var observer = new MutationObserver(function () {
        beautifyOverlay();
    });

    function start() {
        addStyle();
        observer.observe(document.documentElement, {
            childList: true,
            subtree: true,
            characterData: true
        });
        beautifyOverlay();
        console.info('Elementum Web progressive style v2 is active');
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start);
    } else {
        start();
    }
})();
