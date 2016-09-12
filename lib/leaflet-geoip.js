L.GeoIP = L.extend({
    getPosition: function (ip) {
        var ip = (ip !== undefined) ? ip : '?';
        var url = "https://freegeoip.net/json/" + ip;
        var result = L.latLng(0, 0);

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, false);
        xhr.onload = function () {
            var status = xhr.status;
            if (status == 200) {
                var geoip_response = JSON.parse(xhr.responseText);
                result.lat = geoip_response.latitude;
                result.lng = geoip_response.longitude;
            } else {
                console.log("Leaflet.GeoIP.getPosition failed because its XMLHttpRequest got this response: " + xhr.status);
            }
        };
        xhr.send();
        return result;
    },

    centerMapOnPosition: function (map, ip) {
        var position = L.GeoIP.getPosition(ip);
        map.setView(position);
    }
});
