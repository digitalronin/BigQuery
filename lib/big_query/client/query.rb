module BigQuery
  class Client
    module Query
      # Performs the given query in the bigquery api
      #
      # @param options [Hash] query options
      # @option options [Integer] timeoutMs (90_000) timeout in miliseconds
      # @option options [Integer] maxResults (10_000) max results to fetch per page
      # @return [Hash] json api response
      def query(options)
        params = body_params(options)
        params.fetch(:query) # blow up if query not given
        api(
          api_method: @bq.jobs.query,
          body_object: params
        )
      end

      # perform a query synchronously
      # fetch all result rows, even when that takes >1 query
      # invoke /block/ once for each row, passing the row
      #
      # @param options [Hash] query options
      # @option options [Integer] timeoutMs (90_000) timeout in miliseconds
      # @option options [Integer] maxResults (10_000) max results to fetch per page
      def each_row(options, &block)
        current_row = 0
        # repeatedly fetch results, starting from current_row
        # invoke the block on each one, then grab next page if there is one
        # it'll terminate when res has no 'rows' key or when we've done enough rows
        # perform query...
        res = query(options)
        job_id = res['jobReference']['jobId']
        # call the block on the first page of results
        if( res && res['rows'] )
          res['rows'].each(&block)
          current_row += res['rows'].size
        end

        # keep grabbing pages from the API and calling the block on each row
        while(( res = get_query_results(job_id, page_params(current_row, options)) ) && res['rows'] && current_row < res['totalRows'].to_i ) do
          res['rows'].each(&block)
          current_row += res['rows'].size
        end
      end

      private

      def body_params(options)
        {
          timeoutMs:  90_000,
          maxResults: 10_000
        }.merge(options)
      end

      def page_params(current_row, options)
        body = body_params(options)
        {
          startIndex: current_row,
          timeoutMs:  body.fetch(:timeoutMs),
          maxResults: body.fetch(:maxResults)
        }
      end
    end
  end
end
