(function () {
    'use strict';

    if (window.__elementumWebProgressiveV3Installed) {
        return;
    }
    window.__elementumWebProgressiveV3Installed = true;

    var nativeFetch = window.fetch.bind(window);
    var bridgeHost = window.location.hostname.indexOf(':') >= 0
        ? '[' + window.location.hostname + ']'
        : window.location.hostname;
    var bridgeBase = 'http://' + bridgeHost + ':65222';
    var activeRun = 0;
    var requestFinished = false;
    var requestFailed = '';
    var lastRenderKey = '';
    var lastResultCount = 0;

    function injectStyle() {
        if (document.getElementById('elementum-progressive-v3-style')) {
            return;
        }

        var style = document.createElement('style');
        style.id = 'elementum-progressive-v3-style';
        style.textContent = [
            '#elementum-progressive-overlay{position:fixed;inset:0;z-index:2147483000;background:rgba(3,7,18,.84);backdrop-filter:blur(5px);display:flex;align-items:center;justify-content:center;padding:20px;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}',
            '#elementum-progressive-modal{width:min(1180px,97vw);max-height:94vh;display:flex;flex-direction:column;background:linear-gradient(180deg,#161b22 0%,#11161d 100%);color:#e6edf3;border:1px solid #30363d;border-radius:14px;box-shadow:0 24px 90px rgba(0,0,0,.72);overflow:hidden}',
            '#elementum-progressive-head{display:flex;align-items:center;gap:12px;padding:18px 20px;background:rgba(22,27,34,.97);border-bottom:1px solid #30363d}',
            '#elementum-progressive-title{font-size:19px;font-weight:750;flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:#f0f6fc}',
            '#elementum-progressive-count{font-size:12px;font-weight:700;color:#c9d1d9;background:#21262d;border:1px solid #30363d;border-radius:999px;padding:6px 10px;white-space:nowrap}',
            '#elementum-progressive-close{width:34px;height:34px;border:0;border-radius:8px;background:transparent;color:#8b949e;font-size:28px;line-height:1;cursor:pointer;transition:.15s}',
            '#elementum-progressive-close:hover{background:#21262d;color:#f0f6fc}',
            '#elementum-progressive-status{min-height:42px;display:flex;align-items:center;padding:10px 20px;background:#0f141b;border-bottom:1px solid #252b33;color:#9da7b3;font-size:13px}',
            '#elementum-progressive-list{overflow:auto;padding:12px;display:flex;flex-direction:column;gap:9px;scrollbar-color:#3b434d #11161d;scrollbar-width:thin}',
            '#elementum-progressive-list::-webkit-scrollbar{width:10px}',
            '#elementum-progressive-list::-webkit-scrollbar-track{background:#11161d}',
            '#elementum-progressive-list::-webkit-scrollbar-thumb{background:#3b434d;border:2px solid #11161d;border-radius:999px}',
            '.elementum-progressive-item{position:relative;width:100%;text-align:left;background:#1b2129;color:#e6edf3;border:1px solid #30363d;border-radius:10px;padding:13px 15px 14px 17px;cursor:pointer;overflow:hidden;transition:background .14s,border-color .14s,transform .14s,box-shadow .14s}',
            '.elementum-progressive-item:before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:#6e7681}',
            '.elementum-progressive-item[data-quality="4k"]:before,.elementum-progressive-item[data-quality="2160p"]:before{background:#58a6ff}',
            '.elementum-progressive-item[data-quality="1080p"]:before{background:#a371f7}',
            '.elementum-progressive-item[data-quality="720p"]:before{background:#3fb950}',
            '.elementum-progressive-item:hover,.elementum-progressive-item:focus-visible{background:#222a34;border-color:#58a6ff;box-shadow:0 5px 22px rgba(0,0,0,.28);transform:translateY(-1px);outline:none}',
            '.elementum-progressive-item:disabled{opacity:.55;cursor:wait;transform:none}',
            '.elementum-progressive-meta{display:flex;align-items:center;gap:7px;flex-wrap:wrap;margin-bottom:9px}',
            '.elementum-progressive-spacer{flex:1;min-width:10px}',
            '.elementum-progressive-badge{display:inline-flex;align-items:center;min-height:24px;padding:3px 8px;border-radius:6px;background:#252c35;border:1px solid #343c47;color:#c9d1d9;font-size:11px;font-weight:700;line-height:1;white-space:nowrap}',
            '.elementum-progressive-quality{color:#fff;background:#30363d}',
            '.elementum-progressive-quality[data-quality="4k"],.elementum-progressive-quality[data-quality="2160p"]{background:#1f6feb;border-color:#388bfd}',
            '.elementum-progressive-quality[data-quality="1080p"]{background:#6e40c9;border-color:#8957e5}',
            '.elementum-progressive-quality[data-quality="720p"]{background:#238636;border-color:#2ea043}',
            '.elementum-progressive-seeds{color:#7ee787;background:rgba(35,134,54,.18);border-color:rgba(46,160,67,.55)}',
            '.elementum-progressive-peers{color:#d2a8ff;background:rgba(110,64,201,.16);border-color:rgba(137,87,229,.45)}',
            '.elementum-progressive-size{color:#79c0ff;background:rgba(31,111,235,.14);border-color:rgba(56,139,253,.42)}',
            '.elementum-progressive-provider{color:#f0f6fc;background:#30363d;border-color:#484f58}',
            '.elementum-progressive-name{font-size:14px;font-weight:650;line-height:1.45;color:#e6edf3;word-break:break-word}',
            '#elementum-progressive-empty{padding:46px 18px;text-align:center;color:#9da7b3}',
            '.elementum-progressive-spinner{display:inline-block;width:14px;height:14px;border:2px solid #4b5563;border-top-color:#58a6ff;border-radius:50%;animation:elementum-progressive-spin .8s linear infinite;vertical-align:-2px;margin-right:8px}',
            '@keyframes elementum-progressive-spin{to{transform:rotate(360deg)}}',
            '@media(max-width:720px){#elementum-progressive-overlay{padding:0}#elementum-progressive-modal{width:100vw;max-height:100vh;height:100vh;border-radius:0}#elementum-progressive-head{padding:14px 13px}#elementum-progressive-title{font-size:16px}.elementum-progressive-item{padding:12px 11px 13px 14px}.elementum-progressive-spacer{display:none}.elementum-progressive-provider{order:20}}'
        ].join('');
        document.head.appendChild(style);
    }

    function cleanKodiMarkup(value) {
        return String(value || '')
            .replace(/\[(?:\/?B|\/?I|\/COLOR|COLOR(?:\s+|=)[^\]]+)\]/gi, '')
            .replace(/\[CR\]/gi, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    function parseSummary(value) {
        var summary = cleanKodiMarkup(value);
        var result = {
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
            result.releaseType = summary;
            return result;
        }

        result.quality = match[1] || '';
        result.seeds = match[2] || '0';
        result.peers = match[3] || '0';
        result.size = match[4] || '';

        var tail = String(match[5] || '').trim();
        var parts = tail.split(/\s+-\s+/);
        result.releaseType = parts.shift() || '';
        if (parts.length) {
            result.providers = parts.join(' - ').split(',').map(function (item) {
                return item.trim();
            }).filter(function (item) {
                return item.length > 0;
            });
        }

        return result;
    }

    function resultWord(count) {
        var lastTwo = count % 100;
        var last = count % 10;
        if (lastTwo >= 11 && lastTwo <= 14) {
            return 'результатов';
        }
        if (last === 1) {
            return 'результат';
        }
        if (last >= 2 && last <= 4) {
            return 'результата';
        }
        return 'результатов';
    }

    function badge(text, className, title) {
        var element = document.createElement('span');
        element.className = 'elementum-progressive-badge ' + (className || '');
        element.textContent = text;
        if (title) {
            element.title = title;
        }
        return element;
    }

    function getOverlay() {
        return document.getElementById('elementum-progressive-overlay');
    }

    function closeOverlay(sendCancel) {
        activeRun += 1;
        var overlay = getOverlay();
        if (overlay && overlay.parentNode) {
            overlay.parentNode.removeChild(overlay);
        }
        if (sendCancel) {
            nativeFetch(bridgeBase + '/cancel', {method: 'POST'}).catch(function () {});
        }
    }

    function setStatus(message, spinning) {
        var status = document.getElementById('elementum-progressive-status');
        if (!status) {
            return;
        }
        status.textContent = '';
        if (spinning) {
            var spinner = document.createElement('span');
            spinner.className = 'elementum-progressive-spinner';
            status.appendChild(spinner);
        }
        status.appendChild(document.createTextNode(message));
    }

    function openOverlay() {
        injectStyle();
        closeOverlay(false);

        var overlay = document.createElement('div');
        overlay.id = 'elementum-progressive-overlay';

        var modal = document.createElement('div');
        modal.id = 'elementum-progressive-modal';

        var head = document.createElement('div');
        head.id = 'elementum-progressive-head';

        var title = document.createElement('div');
        title.id = 'elementum-progressive-title';
        title.textContent = 'Поиск торрентов';

        var count = document.createElement('div');
        count.id = 'elementum-progressive-count';
        count.textContent = '0 результатов';

        var close = document.createElement('button');
        close.id = 'elementum-progressive-close';
        close.type = 'button';
        close.title = 'Отмена';
        close.textContent = '×';
        close.addEventListener('click', function () {
            closeOverlay(true);
        });

        var status = document.createElement('div');
        status.id = 'elementum-progressive-status';
        status.innerHTML = '<span class="elementum-progressive-spinner"></span>Запуск поиска…';

        var list = document.createElement('div');
        list.id = 'elementum-progressive-list';

        var empty = document.createElement('div');
        empty.id = 'elementum-progressive-empty';
        empty.textContent = 'Ожидаем первые результаты провайдеров…';
        list.appendChild(empty);

        head.appendChild(title);
        head.appendChild(count);
        head.appendChild(close);
        modal.appendChild(head);
        modal.appendChild(status);
        modal.appendChild(list);
        overlay.appendChild(modal);
        document.body.appendChild(overlay);

        overlay.addEventListener('click', function (event) {
            if (event.target === overlay) {
                closeOverlay(true);
            }
        });
    }

    function selectTorrent(choice, button) {
        var buttons = document.querySelectorAll('.elementum-progressive-item');
        Array.prototype.forEach.call(buttons, function (item) {
            item.disabled = true;
        });
        setStatus('Запускаем выбранный торрент…', true);

        nativeFetch(bridgeBase + '/select', {
            method: 'POST',
            headers: {'Content-Type': 'text/plain;charset=UTF-8'},
            body: JSON.stringify({choice: choice})
        }).then(function (response) {
            if (!response.ok) {
                throw new Error('Bridge HTTP ' + response.status);
            }
            button.style.borderColor = '#3fb950';
            window.setTimeout(function () {
                closeOverlay(false);
            }, 250);
        }).catch(function (error) {
            Array.prototype.forEach.call(buttons, function (item) {
                item.disabled = false;
            });
            setStatus('Не удалось выбрать торрент: ' + String(error), false);
        });
    }

    function renderItem(rawItem, index) {
        var lines = String(rawItem || '').split('\n');
        var parsed = parseSummary(lines[0]);
        var qualityKey = String(parsed.quality || '').toLowerCase();
        var title = cleanKodiMarkup(lines[1] || parsed.fallback || lines[0]);

        var button = document.createElement('button');
        button.type = 'button';
        button.className = 'elementum-progressive-item';
        button.setAttribute('data-quality', qualityKey);

        var meta = document.createElement('div');
        meta.className = 'elementum-progressive-meta';

        if (parsed.quality) {
            var quality = badge(parsed.quality, 'elementum-progressive-quality', 'Разрешение');
            quality.setAttribute('data-quality', qualityKey);
            meta.appendChild(quality);
        }
        if (parsed.seeds !== '') {
            meta.appendChild(badge('● ' + parsed.seeds + ' сидов', 'elementum-progressive-seeds', 'Количество раздающих'));
        }
        if (parsed.peers !== '') {
            meta.appendChild(badge('○ ' + parsed.peers + ' пиров', 'elementum-progressive-peers', 'Количество скачивающих'));
        }
        if (parsed.size) {
            meta.appendChild(badge(parsed.size, 'elementum-progressive-size', 'Размер'));
        }
        if (parsed.releaseType) {
            meta.appendChild(badge(parsed.releaseType, '', 'Тип релиза'));
        }

        var spacer = document.createElement('span');
        spacer.className = 'elementum-progressive-spacer';
        meta.appendChild(spacer);

        parsed.providers.forEach(function (provider) {
            meta.appendChild(badge(provider, 'elementum-progressive-provider', 'Провайдер'));
        });

        var name = document.createElement('div');
        name.className = 'elementum-progressive-name';
        name.textContent = title;

        button.appendChild(meta);
        button.appendChild(name);
        button.addEventListener('click', function () {
            selectTorrent(index, button);
        });

        return button;
    }

    function renderState(state) {
        var overlay = getOverlay();
        if (!overlay || !state || !state.active) {
            return;
        }

        var items = Array.isArray(state.items) ? state.items : [];
        var renderKey = String(state.session || '') + ':' + String(state.updated_at || '') + ':' + items.length;
        if (renderKey === lastRenderKey) {
            return;
        }
        lastRenderKey = renderKey;
        lastResultCount = items.length;

        var title = document.getElementById('elementum-progressive-title');
        var count = document.getElementById('elementum-progressive-count');
        var list = document.getElementById('elementum-progressive-list');
        if (!title || !count || !list) {
            return;
        }

        title.textContent = cleanKodiMarkup(state.title) || 'Выберите торрент';
        count.textContent = items.length + ' ' + resultWord(items.length);
        setStatus('Результаты добавляются по мере ответа провайдеров', true);

        list.textContent = '';
        if (!items.length) {
            var empty = document.createElement('div');
            empty.id = 'elementum-progressive-empty';
            empty.textContent = 'Провайдеры пока не вернули подходящих торрентов…';
            list.appendChild(empty);
            return;
        }

        items.forEach(function (rawItem, index) {
            list.appendChild(renderItem(rawItem, index));
        });
    }

    function pollState(runId, startedAt) {
        if (runId !== activeRun || !getOverlay()) {
            return;
        }

        nativeFetch(bridgeBase + '/state', {cache: 'no-store'})
            .then(function (response) {
                if (!response.ok) {
                    throw new Error('Bridge HTTP ' + response.status);
                }
                return response.json();
            })
            .then(function (state) {
                if (runId !== activeRun || !getOverlay()) {
                    return;
                }

                if (state.active) {
                    renderState(state);
                    if (state.done) {
                        closeOverlay(false);
                        return;
                    }
                } else if (requestFinished) {
                    if (requestFailed) {
                        setStatus('Ошибка запуска поиска: ' + requestFailed, false);
                    } else {
                        setStatus('Запрос завершён без окна выбора торрента', false);
                        window.setTimeout(function () {
                            closeOverlay(false);
                        }, 1200);
                        return;
                    }
                } else if (Date.now() - startedAt > 15000 && lastResultCount === 0) {
                    setStatus('Поиск выполняется, но первые результаты ещё не получены…', true);
                }

                if (Date.now() - startedAt > 240000 && lastResultCount === 0) {
                    setStatus('Превышено время ожидания первых результатов', false);
                    return;
                }

                window.setTimeout(function () {
                    pollState(runId, startedAt);
                }, 500);
            })
            .catch(function (error) {
                if (runId !== activeRun || !getOverlay()) {
                    return;
                }
                setStatus('Web bridge недоступен: ' + String(error), false);
                window.setTimeout(function () {
                    pollState(runId, startedAt);
                }, 1500);
            });
    }

    function isTorrentSelectionRequest(input) {
        var rawUrl = typeof input === 'string'
            ? input
            : (input && input.url ? input.url : '');
        if (!rawUrl) {
            return false;
        }

        var url;
        try {
            url = new URL(rawUrl, window.location.href);
        } catch (error) {
            return false;
        }

        if (!url.searchParams.has('external')) {
            return false;
        }

        return /\/(?:links|forcelinks|download)(?:\/|$)/i.test(url.pathname);
    }

    function startWebSelection(input, init) {
        openOverlay();
        requestFinished = false;
        requestFailed = '';
        lastRenderKey = '';
        lastResultCount = 0;
        var runId = ++activeRun;
        var startedAt = Date.now();

        nativeFetch(bridgeBase + '/arm', {method: 'POST'})
            .then(function (response) {
                if (!response.ok) {
                    throw new Error('Bridge HTTP ' + response.status);
                }

                nativeFetch(input, init)
                    .then(function () {
                        requestFinished = true;
                    })
                    .catch(function (error) {
                        requestFailed = String(error);
                        requestFinished = true;
                    });

                pollState(runId, startedAt);
            })
            .catch(function (error) {
                requestFailed = String(error);
                requestFinished = true;
                setStatus('Не удалось включить Web bridge: ' + requestFailed, false);
            });
    }

    window.fetch = function (input, init) {
        if (!isTorrentSelectionRequest(input)) {
            return nativeFetch(input, init);
        }

        startWebSelection(input, init);
        return Promise.resolve(new Response('{}', {
            status: 200,
            headers: {'Content-Type': 'application/json'}
        }));
    };

    console.info('Elementum progressive torrent selector v3 is active');
})();
