$(function () {

    class Params {
        constructor(htmlWidth) {

            this.firstPasukFontSize = 3;
            this.secondPasukFontSize = 3;
            this.tajPasukFontSize = 3;

            this.firstPasukLineHeight = 4;
            this.secondPasukLineHeight = 4;
            this.tajPasukLineHeight = 4;

            this.firstPasukFontColor = 'DarkRed';
            this.secondPasukFontColor = 'DarkGreen';
            this.tajPasukFontColor = 'DarkBlue';

            this.transformScaleY = 'scaleY(1.2)';

            this.firstPasukFontFamily = 'SBLBibLit';
            this.secondPasukFontFamily = 'SBLBibLit';
            this.tajPasukFontFamily = 'SBLBibLit';

            this.firstPasukFontWeight = 'normal';
            this.secondPasukFontWeight = 'normal';
            this.tajPasukFontWeight = 'normal';

            this.fontSizeTypeDesc = 'vw';
            this.lineHeightTypeDesc = 'vw';

            this.pasukPaddingTop = '12px';
            this.pasukPaddingBottom = '26px';

            this.divPasukPadding = '44px';

            this.firstPasukPaddingTop = '3vw';
            this.firstPasukPadding = '44px';
            this.secondPasukPadding = '44px';
            this.tajPasukPadding = '44px';
            this.tajPasukPaddingBotton = '3vw';

            if (htmlWidth <= 1080) {
                this.firstPasukFontSize = 6;
                this.secondPasukFontSize = 6;
                this.tajPasukFontSize = 6;

                this.firstPasukLineHeight = 7;
                this.secondPasukLineHeight = 7;
                this.tajPasukLineHeight = 7;

                this.pasukPaddingTop = '22px';
                this.pasukPaddingBottom = '36px';

                this.divPasukPadding = '44px';

                this.firstPasukPaddingTop = '8vw';
                this.firstPasukPadding = '1vw';
                this.secondPasukPadding = '1vw';
                this.tajPasukPadding = '1vw';
                this.tajPasukPaddingBotton = '8vw';

                return;
            }

            if (htmlWidth <= 900) {
                this.firstPasukFontSize = 5;
                this.secondPasukFontSize = 5;
                this.tajPasukFontSize = 5;

                this.firstPasukLineHeight = 6;
                this.secondPasukLineHeight = 6;
                this.tajPasukLineHeight = 6;

                this.pasukPaddingTop = '22px';
                this.pasukPaddingBottom = '36px';

                this.divPasukPadding = '18px';

                this.firstPasukPaddingTop = '10vw';
                this.firstPasukPadding = '1vw';
                this.secondPasukPadding = '1vw';
                this.tajPasukPadding = '1vw';
                this.tajPasukPaddingBotton = '10vw';

                return;
            }
        }
    }

    $.fn.isOnScreen = function () {

        var win = $(window);

        var viewport = {
            top: win.scrollTop(),
            left: win.scrollLeft()
        };
        viewport.right = viewport.left + win.width();
        viewport.bottom = viewport.top + win.height();

        var paddingBottom = 700;
        var paddingDiv2Passok = 100;

        // Draw viewport
        $('#viewportDiv').height(win.height() - paddingBottom);
        $('#viewportDiv').width(win.width());
        $('#viewportDiv').css('left', viewport.left);
        $('#viewportDiv').css('top', 1);

        //console.log(viewport);
        //console.log(`win - scrollTop: ${win.scrollTop()}, Height: ${win.height()}, Width: ${win.width()}, `);

        viewport.bottom -= paddingBottom;

        var bounds = this.offset();
        bounds.top += paddingDiv2Passok;
        bounds.right = bounds.left + this.outerWidth();
        bounds.bottom = bounds.top + this.outerHeight();

        bounds.bottom += paddingDiv2Passok;

        var res = !(viewport.right < bounds.left || viewport.left > bounds.right || viewport.bottom < bounds.top || viewport.top > bounds.bottom);

        if (res == true) {
            // Draw viewport
            /*$('#viewportDiv').height(viewport.bottom - viewport.top);
            $('#viewportDiv').width(viewport.right - viewport.left);
            $('#viewportDiv').css('left', viewport.left);
            $('#viewportDiv').css('top', viewport.top);*/

            console.log(`win - scrollTop: ${win.scrollTop()}, Height: ${win.height()}, Width: ${win.width()}, `);

        }

        return res;
    };

    $.removeNonAscii = function (str) {

        if ((str === null) || (str === ''))
            return false;
        else
            str = str.toString();

        return str.replace(/[^\x20-\x7E]/g, '');
    };


});
