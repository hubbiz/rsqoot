module RSqoot
  module Coupon

    # Retrieve a list of coupons based on the following parameters
    #
    # @param [String] query (Search coupons by title, description, fine print, merchant name, provider, and category.)
    # @param [String] location (Limit results to a particular area. We'll resolve whatever you pass us (including an IP address) to coordinates and search near there.)
    # @param [Integer] radius (Measured in miles. Defaults to 10.)
    # @param [Integer] page (Which page of result to return. Default to 1.)
    # @param [Integer] per_page (Number of results to return at once. Defaults to 10.)
    #
    def coupons(options = {})
      options = update_by_expire_time options
      if coupons_not_latest?(options)
        uniq = !!options.delete(:uniq)
        @rsqoot_coupons = get('coupons', options, SqootCoupon) || []
        @rsqoot_coupons = @rsqoot_coupons.coupons.map(&:coupon) unless @rsqoot_coupons.empty?
        @rsqoot_coupons = uniq_coupons(@rsqoot_coupons) if uniq
      end
      logger(uri: sqoot_query_uri, records: @rsqoot_coupons, type: 'coupons', opts: options)
      @rsqoot_coupons
    end

    # Retrieve a coupon by id
    #
    def coupon(id, options = {})
      options = update_by_expire_time options
      if coupon_not_latest?(id)
        @rsqoot_coupon = get("coupons/#{id}", options, SqootCoupon)
        @rsqoot_coupon = @rsqoot_coupon.coupon if @rsqoot_coupon
      end
      logger(uri: sqoot_query_uri, records: [@rsqoot_coupon], type: 'coupon', opts: options)
      @rsqoot_coupon
    end

    def impression(coupon_id, options = {})
      url_generator("coupons/#{coupon_id}/image", options, true).first.to_s
    end

    # Auto Increment for coupons query.
    def total_sqoot_coupons(options = {})
      @total_coupons  ||= []
      @cached_pages ||= []
      page = options[:page] || 1
      check_query_change options
      unless page_cached? page
        @total_coupons += coupons(options)
        @total_coupons.uniq!
        @cached_pages << page.to_s
        @cached_pages.uniq!
      end
      @total_coupons
    end

    private

    attr_reader :cached_pages, :total_coupons, :last_coupons_query

    # Uniq coupons from Sqoot, because there are some many duplicated coupons
    # with different ids
    # Simplely distinguish them by their titles
    #
    def uniq_coupons(coupons = [])
      titles = coupons.map(&:title).uniq
      titles.map do |title|
        coupons.map do |coupon|
          coupon if coupon.try(:title) == title
        end.compact.last
      end.flatten
    end

    # A status checker for method :total_sqoot_coupons
    # If the query parameters changed, this will reset the cache
    # else it will do nothing
    #
    def check_query_change(options = {})
      options = update_by_expire_time options
      @last_coupons_query ||= ''
      current_query = options[:query].to_s
      current_query += options[:category_slugs].to_s
      current_query += options[:location].to_s
      current_query += options[:radius].to_s
      current_query += options[:online].to_s
      current_query += options[:expired_in].to_s
      current_query += options[:per_page].to_s
      if @last_coupons_query != current_query
        @last_coupons_query = current_query
        @total_coupons  = []
        @cached_pages = []
      end
    end

    # Helper methods to detect which page is cached
    #
    def page_cached?(page = 1)
      cached_pages.include? page.to_s
    end
  end
end
