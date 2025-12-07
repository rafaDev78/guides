public class BoEEXchangeService {
  public class BoEException extends Exception {
  }

  private static final String BOE_ENDPOINT = 'https://www.bankofengland.co.uk/boeapps/database/_iadb-fromshowcolumns.asp';

  /**
   * @description Fetch rate real-time. Handles weekends by looking back in memory.
   */
  public static Decimal getRateForDate(String seriesCode, Date targetDate) {
    System.debug('--- INITIATING REAL-TIME FETCH for ' + targetDate);

    // 1. Define a 7-day lookback window to ensure we find a valid trading day
    Date startDate = targetDate.addDays(-7);

    // 2. Perform Callout
    String csvBody = fetchRatesRaw(seriesCode, startDate, targetDate);

    // 3. Parse CSV into an In-Memory Map (Date -> Rate)
    Map<Date, Decimal> ratesMap = parseCsvToMap(csvBody);

    // 4. Execute Lookback Logic in Memory
    // Start at the Target Date. If null, step back 1 day. Repeat.
    Date cursorDate = targetDate;

    while (cursorDate >= startDate) {
      if (ratesMap.containsKey(cursorDate)) {
        Decimal foundRate = ratesMap.get(cursorDate);
        System.debug('--- MATCH FOUND: ' + foundRate + ' on ' + cursorDate);
        return foundRate;
      }
      cursorDate = cursorDate.addDays(-1);
    }

    throw new BoEException(
      'No rate found for ' +
        seriesCode +
        ' between ' +
        startDate +
        ' and ' +
        targetDate
    );
  }

  private static String fetchRatesRaw(
    String seriesCode,
    Date fromDate,
    Date toDate
  ) {
    Http http = new Http();
    HttpRequest req = new HttpRequest();

    String dFrom = EncodingUtil.urlEncode(formatBoEDate(fromDate), 'UTF-8');
    String dTo = EncodingUtil.urlEncode(formatBoEDate(toDate), 'UTF-8');

    String params =
      '?csv.x=yes' +
      '&SeriesCodes=' +
      seriesCode +
      '&DateFrom=' +
      dFrom +
      '&DateTo=' +
      dTo +
      '&CSVF=TN' +
      '&UsingCodes=Y' +
      '&VPD=Y' +
      '&VFD=N';

    req.setEndpoint(BOE_ENDPOINT + params);
    req.setMethod('GET');
    req.setHeader('User-Agent', 'Salesforce/Apex');

    HttpResponse res = http.send(req);

    if (res.getStatusCode() == 200) {
      return res.getBody();
    } else {
      throw new BoEException('BoE Callout Failed: ' + res.getStatus());
    }
  }

  private static Map<Date, Decimal> parseCsvToMap(String csvBody) {
    Map<Date, Decimal> resultMap = new Map<Date, Decimal>();
    List<String> lines = csvBody.split('\n');

    for (String line : lines) {
      line = line.trim();
      if (String.isBlank(line) || !line.contains(','))
        continue;

      try {
        List<String> parts = line.split(',');
        String dateStr = parts[0].trim();
        String valStr = parts[1].trim();

        if (!valStr.contains('.'))
          continue; // Skip headers

        Date d = parseBoEDate(dateStr);
        Decimal v = Decimal.valueOf(valStr);

        resultMap.put(d, v);
      } catch (Exception e) {
        // Swallow parsing errors for bad lines
      }
    }
    return resultMap;
  }

  // --- UTILITIES ---
  private static String formatBoEDate(Date d) {
    DateTime dt = DateTime.newInstance(d.year(), d.month(), d.day());
    return dt.format('dd/MMM/yyyy');
  }

  private static Date parseBoEDate(String dStr) {
    Map<String, Integer> monthMap = new Map<String, Integer>{
      'Jan' => 1,
      'Feb' => 2,
      'Mar' => 3,
      'Apr' => 4,
      'May' => 5,
      'Jun' => 6,
      'Jul' => 7,
      'Aug' => 8,
      'Sep' => 9,
      'Oct' => 10,
      'Nov' => 11,
      'Dec' => 12
    };
    List<String> parts = dStr.split(' ');
    return Date.newInstance(
      Integer.valueOf(parts[2]),
      monthMap.get(parts[1]),
      Integer.valueOf(parts[0])
    );
  }
}


//try {
// Test: 23 April 2023 (Sunday). Should return approx 0.88 (Friday's rate).
//   Decimal rate = BoEExchangeService.getRateForDate(
//     'XUDLERS',
//     Date.newInstance(2023, 4, 23)
//   );
//   System.debug('SUCCESS: Rate is ' + rate);
// } catch (Exception e) {
//   System.debug('ERROR: ' + e.getMessage());
// }
