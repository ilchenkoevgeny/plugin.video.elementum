(function () {
    'use strict';

    if (window.__elementumWebProgressiveV3LayoutFix) {
        return;
    }
    window.__elementumWebProgressiveV3LayoutFix = true;

    var style = document.createElement('style');
    style.id = 'elementum-progressive-v3-layout-fix';
    style.textContent = [
        '#elementum-progressive-modal{min-height:0!important}',
        '#elementum-progressive-head,#elementum-progressive-status{flex:0 0 auto!important}',
        '#elementum-progressive-list{flex:1 1 auto!important;min-height:0!important;overflow-y:auto!important;overflow-x:hidden!important}',
        '.elementum-progressive-item{display:block!important;flex:0 0 auto!important;min-height:76px!important;height:auto!important;box-sizing:border-box!important}',
        '.elementum-progressive-meta{display:flex!important;flex:0 0 auto!important;min-height:24px!important;margin-bottom:9px!important}',
        '.elementum-progressive-name{display:block!important;flex:0 0 auto!important;min-height:20px!important;height:auto!important;overflow:visible!important;white-space:normal!important}',
        '@media(max-width:720px){.elementum-progressive-item{min-height:82px!important}}'
    ].join('');
    document.head.appendChild(style);

    var savedScrollTop = 0;
    var observedList = null;
    var listObserver = null;

    function attachList() {
        var list = document.getElementById('elementum-progressive-list');
        if (!list || list === observedList) {
            return;
        }

        if (listObserver) {
            listObserver.disconnect();
        }

        observedList = list;
        savedScrollTop = list.scrollTop || 0;

        list.addEventListener('scroll', function () {
            savedScrollTop = list.scrollTop || 0;
        }, {passive: true});

        listObserver = new MutationObserver(function () {
            window.requestAnimationFrame(function () {
                if (observedList && document.body.contains(observedList)) {
                    observedList.scrollTop = savedScrollTop;
                }
            });
        });

        listObserver.observe(list, {
            childList: true
        });
    }

    var documentObserver = new MutationObserver(attachList);
    documentObserver.observe(document.documentElement, {
        childList: true,
        subtree: true
    });
    attachList();

    console.info('Elementum progressive v3 layout fix is active');
})();
