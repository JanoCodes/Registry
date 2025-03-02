module Epp
  class DomainsController < BaseController
    before_action :find_domain, only: %i[info renew update transfer delete]
    before_action :find_password, only: %i[info update transfer delete]

    def info
      authorize! :info, @domain

      @hosts = params[:parsed_frame].css('name').first['hosts'] || 'all'

      sponsoring_registrar = (@domain.registrar == current_user.registrar)
      correct_transfer_code_provided = (@domain.transfer_code == @password)
      @reveal_full_details = (sponsoring_registrar || correct_transfer_code_provided)

      case @hosts
      when 'del'
        @nameservers = @domain.delegated_nameservers.sort
      when 'sub'
        @nameservers = @domain.subordinate_nameservers.sort
      when 'all'
        @nameservers = @domain.nameservers.sort
      end

      render_epp_response '/epp/domains/info'
    end

    def create
      authorize! :create, Epp::Domain

      if Domain.release_to_auction
        request_domain_name = params[:parsed_frame].css('name').text.strip.downcase
        domain_name = DNS::DomainName.new(SimpleIDN.to_unicode(request_domain_name))

        if domain_name.at_auction?
          epp_errors << {
            code: '2306',
            msg: 'Parameter value policy error: domain is at auction',
          }
          handle_errors
          return
        elsif domain_name.awaiting_payment?
          epp_errors << {
            code: '2003',
            msg: 'Required parameter missing; reserved>pw element required for reserved domains',
          }
          handle_errors
          return
        elsif domain_name.pending_registration?
          registration_code = params[:parsed_frame].css('reserved > pw').text

          if registration_code.empty?
            epp_errors << {
              code: '2003',
              msg: 'Required parameter missing; reserved>pw element is required',
            }
            handle_errors
            return
          end

          unless domain_name.available_with_code?(registration_code)
            epp_errors << {
              code: '2202',
              msg: 'Invalid authorization information; invalid reserved>pw value',
            }
            handle_errors
            return
          end
        end
      end

      @domain = Epp::Domain.new_from_epp(params[:parsed_frame], current_user)
      handle_errors(@domain) and return if @domain.errors.any?
      @domain.valid?
      @domain.errors.delete(:name_dirty) if @domain.errors[:puny_label].any?
      handle_errors(@domain) and return if @domain.errors.any?
      handle_errors and return unless balance_ok?('create') # loads pricelist in this method

      ActiveRecord::Base.transaction do
        @domain.add_legal_file_to_new(params[:parsed_frame])

        if @domain.save # TODO: Maybe use validate: false here because we have already validated the domain?
          current_user.registrar.debit!({
                                          sum: @domain_pricelist.price.amount,
                                          description: "#{I18n.t('create')} #{@domain.name}",
                                          activity_type: AccountActivity::CREATE,
                                          price: @domain_pricelist
                                        })

          if Domain.release_to_auction && domain_name.pending_registration?
            active_auction = Auction.find_by(domain: domain_name.to_s,
                                             status: Auction.statuses[:payment_received])
            active_auction.domain_registered!
          end

          render_epp_response '/epp/domains/create'
        else
          handle_errors(@domain)
        end
      end
    end

    def update
      authorize! :update, @domain, @password

      if @domain.update(params[:parsed_frame], current_user)
        if @domain.epp_pending_update.present?
          render_epp_response '/epp/domains/success_pending'
        else
          render_epp_response '/epp/domains/success'
        end
      else
        handle_errors(@domain)
      end
    end

    def delete
      authorize! :delete, @domain, @password

      handle_errors(@domain) and return unless @domain.can_be_deleted?

      if @domain.epp_destroy(params[:parsed_frame], current_user.id)
        if @domain.epp_pending_delete.present?
          render_epp_response '/epp/domains/success_pending'
        else
          render_epp_response '/epp/domains/success'
        end
      else
        handle_errors(@domain)
      end
    end

    def check
      authorize! :check, Epp::Domain

      domain_names = params[:parsed_frame].css('name').map(&:text)
      @domains = Epp::Domain.check_availability(domain_names)
      render_epp_response '/epp/domains/check'
    end

    def renew
      authorize! :renew, @domain

      period_element = params[:parsed_frame].css('period').text
      period = (period_element.to_i == 0) ? 1 : period_element.to_i
      period_unit = Epp::Domain.parse_period_unit_from_frame(params[:parsed_frame]) || 'y'

      balance_ok?('renew', period, period_unit) # loading pricelist

      begin
        ActiveRecord::Base.transaction(isolation: :serializable) do
          @domain.reload

          success = @domain.renew(
            params[:parsed_frame].css('curExpDate').text,
            period, period_unit
          )

          if success
            unless balance_ok?('renew', period, period_unit)
              handle_errors
              fail ActiveRecord::Rollback
            end

            current_user.registrar.debit!({
                                            sum: @domain_pricelist.price.amount,
                                            description: "#{I18n.t('renew')} #{@domain.name}",
                                            activity_type: AccountActivity::RENEW,
                                            price: @domain_pricelist
                                          })

            render_epp_response '/epp/domains/renew'
          else
            handle_errors(@domain)
          end
        end
      rescue ActiveRecord::StatementInvalid => e
        sleep rand / 100
        retry
      end
    end

    def transfer
      authorize! :transfer, @domain
      action = params[:parsed_frame].css('transfer').first[:op]

      if @domain.non_transferable?
        epp_errors << {
          code: '2304',
          msg: I18n.t(:object_status_prohibits_operation),
        }
        handle_errors
        return
      end

      provided_transfer_code = params[:parsed_frame].css('authInfo pw').text
      wrong_transfer_code = provided_transfer_code != @domain.transfer_code

      if wrong_transfer_code
        epp_errors << {
          code: '2202',
          msg: 'Invalid authorization information',
        }
        handle_errors
        return
      end

      @domain_transfer = @domain.transfer(params[:parsed_frame], action, current_user)

      if @domain.errors[:epp_errors].any?
        handle_errors(@domain)
        return
      end

      if @domain_transfer
        render_epp_response '/epp/domains/transfer'
      else
        epp_errors << {
          code: '2303',
          msg: I18n.t('no_transfers_found')
        }
        handle_errors
      end
    end

    private

    def validate_info
      @prefix = 'info > info >'
      requires('name')
      optional_attribute 'name', 'hosts', values: %(all, sub, del, none)
    end

    def validate_create
      if Domain.nameserver_required?
        @prefix = 'create > create >'
        requires 'name', 'ns', 'registrant', 'ns > hostAttr'
      end

      @prefix = 'extension > create >'
      mutually_exclusive 'keyData', 'dsData'

      @prefix = nil
      requires 'extension > extdata > legalDocument'

      optional_attribute 'period', 'unit', values: %w(d m y)

      status_editing_disabled
    end

    def validate_update
      if element_count('update > chg > registrant') > 0
        requires 'extension > extdata > legalDocument'
      end

      @prefix = 'update > update >'
      requires 'name'

      status_editing_disabled
    end

    def validate_delete
      requires 'extension > extdata > legalDocument'

      @prefix = 'delete > delete >'
      requires 'name'
    end

    def validate_check
      @prefix = 'check > check >'
      requires('name')
    end

    def validate_renew
      @prefix = 'renew > renew >'
      requires 'name', 'curExpDate'

      optional_attribute 'period', 'unit', values: %w(d m y)
    end

    def validate_transfer
      # period element is disabled for now
      if params[:parsed_frame].css('period').any?
        epp_errors << {
          code: '2307',
          msg: I18n.t(:unimplemented_object_service),
          value: { obj: 'period' }
        }
      end

      requires 'transfer > transfer'

      @prefix = 'transfer > transfer >'
      requires 'name'

      @prefix = nil
      requires_attribute 'transfer', 'op', values: %(approve, query, reject, request, cancel)
    end

    def find_domain
      domain_name = params[:parsed_frame].css('name').text.strip.downcase

      domain = Epp::Domain.find_by_idn(domain_name)
      raise ActiveRecord::RecordNotFound unless domain

      @domain = domain
    end

    def find_password
      @password = params[:parsed_frame].css('authInfo pw').text
    end

    def status_editing_disabled
      return true if Setting.client_status_editing_enabled
      return true if params[:parsed_frame].css('status').empty?
      epp_errors << {
        code: '2306',
        msg: "#{I18n.t(:client_side_status_editing_error)}: status [status]"
      }
    end

    def balance_ok?(operation, period = nil, unit = nil)
      @domain_pricelist = @domain.pricelist(operation, period.try(:to_i), unit)
      if @domain_pricelist.try(:price) # checking if price list is not found
        if current_user.registrar.balance < @domain_pricelist.price.amount
          epp_errors << {
            code: '2104',
            msg: I18n.t('billing_failure_credit_balance_low')
          }
          return false
        end
      else
        epp_errors << {
          code: '2104',
          msg: I18n.t(:active_price_missing_for_this_operation)
        }
        return false
      end
      true
    end
  end
end
