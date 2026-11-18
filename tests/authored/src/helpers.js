// Shared helpers for every test script in this collection.
// Postman scripts cannot import each other, so the code lives in one function,
// its text is saved in a collection variable, and each test script loads it with eval().
function buildHelpers() {
    // The API stores latitude and longitude with 6 decimals and speed and heading with 2.
    const round = (value, places) => Number(value.toFixed(places));

    return {

        // The response must have exactly this HTTP status code.
        expectStatus(code) {
            pm.test(`Status is ${code}`, () => {
                pm.response.to.have.status(code);
            });
        },

        // Every error response must be JSON of the form { "error": "some text" }.
        expectError() {
            pm.test('Body is { "error": "..." }', () => {
                const body = pm.response.json();
                pm.expect(body).to.have.property('error');
                pm.expect(body.error).to.be.a('string').and.not.empty;
            });
        },

        // Reads the position back with GET /positions/{id} and checks what was stored.
        expectStored(sent) {
            pm.sendRequest({
                url: `${pm.variables.get('baseUrl')}/positions/${encodeURIComponent(sent.id)}`,
                method: 'GET',
                header: { 'X-Api-Key': pm.variables.get('apiKey') }
            }, (error, response) => {
                pm.test('GET by id returns the stored position', () => {
                    pm.expect(error, 'request error').to.equal(null);
                    pm.expect(response.code, 'status').to.equal(200);

                    const stored = response.json();
                    pm.expect(stored.id, 'id').to.equal(sent.id);
                    pm.expect(stored.deviceId, 'deviceId').to.equal(sent.deviceId);
                    pm.expect(new Date(stored.occurredAt).getTime(), 'occurredAt').to.equal(new Date(sent.occurredAt).getTime());
                    pm.expect(stored.latitude, 'latitude').to.equal(round(sent.latitude, 6));
                    pm.expect(stored.longitude, 'longitude').to.equal(round(sent.longitude, 6));
                    pm.expect(stored.speedKph, 'speedKph').to.equal(round(sent.speedKph, 2));
                    pm.expect(stored.headingDeg, 'headingDeg').to.equal(round(sent.headingDeg, 2));

                });
            });
        },

        // The response body must be a position with exactly these values.
        expectPosition(expected) {
            pm.test(`Body is the position ${expected.id}`, () => {
                const stored = pm.response.json();
                pm.expect(stored.id, 'id').to.equal(expected.id);
                pm.expect(stored.deviceId, 'deviceId').to.equal(expected.deviceId);
                pm.expect(new Date(stored.occurredAt).getTime(), 'occurredAt').to.equal(new Date(expected.occurredAt).getTime());
                pm.expect(stored.latitude, 'latitude').to.equal(expected.latitude);
                pm.expect(stored.longitude, 'longitude').to.equal(expected.longitude);
                pm.expect(stored.speedKph, 'speedKph').to.equal(expected.speedKph);
                pm.expect(stored.headingDeg, 'headingDeg').to.equal(expected.headingDeg);
            });
        },

        // The "value" array must contain exactly these ids, in exactly this order.
        expectIds(expectedIds) {
            pm.test(`value has ${expectedIds.length} item(s) in the expected order`, () => {
                const ids = pm.response.json().value.map((item) => item.id);
                pm.expect(ids).to.eql(expectedIds);
            });
        },

        // "@odata.count" must be present and equal to this total (the number of ALL matching rows, not just the page).
        expectCount(total) {
            pm.test(`@odata.count is ${total}`, () => {
                pm.expect(pm.response.json()['@odata.count']).to.equal(total);
            });
        },

        // "@odata.count" must not be in the response at all (it is only returned when $count=true).
        expectNoCount() {
            pm.test('Response has no @odata.count', () => {
                pm.expect(pm.response.json()).to.not.have.property('@odata.count');
            });
        },

        // Every item must be at or after (asc) or at or before (desc) the item before it, by occurredAt.
        expectSortedByOccurredAt(direction) {
            pm.test(`Items are sorted by occurredAt ${direction}`, () => {
                const times = pm.response.json().value.map((item) => new Date(item.occurredAt).getTime());
                for (let i = 1; i < times.length; i++) {
                    if (direction === 'asc') {
                        pm.expect(times[i], `item ${i}`).to.be.at.least(times[i - 1]);
                    } else {
                        pm.expect(times[i], `item ${i}`).to.be.at.most(times[i - 1]);
                    }
                }
            });
        },

        // With $count=true and no $top, @odata.count must equal the number of items returned.
        expectCountMatchesItems() {
            pm.test('@odata.count matches the number of items', () => {
                const body = pm.response.json();
                pm.expect(body['@odata.count']).to.equal(body.value.length);
            });
        }
    };
}

pm.collectionVariables.set('helpers', buildHelpers.toString());
