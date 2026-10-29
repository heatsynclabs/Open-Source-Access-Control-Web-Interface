# The site header: which links a person sees, and which one is current.
module NavigationHelper
  # A link in the header nav. It is marked current when the page belongs to
  # one of the given controllers, so every page of a section lights its link.
  def nav_link(label, path, controllers:)
    current = Array(controllers).map(&:to_s).include?(controller_name)
    link_to label, path, class: ("on" if current), "aria-current": ("page" if current)
  end

  # The role groups under the main nav: [group label, [[label, path, controllers], ...]].
  # Each link appears only when the signed-in person may use that page; a group
  # with no links is left out.
  def manage_nav_groups
    groups = [
      ["Instructor", [
        (["Cert classes", certifications_path, :certifications] if can?(:create, UserCertification)),
        (["User certs", user_certifications_path, :user_certifications] if can?(:create, UserCertification)),
        (["Add member", new_user_path, :none] if can?(:create, User)),
      ]],
      ["Treasurer", [
        (["Payments", payments_path, :payments] if can?(:create, Payment)),
        (["PayPal", paypal_csvs_path, :paypal_csvs] if can?(:manage, PaypalCsv)),
        (["IPN", ipns_path, :ipns] if can?(:manage, Ipn)),
      ]],
      ["Admin", [
        (["Cards", cards_path, :cards] if can?(:manage, Card)),
        (["Door log", door_logs_path, :door_logs] if can?(:read, DoorLog)),
        (["Waivers", contracts_path, :contracts] if can?(:read, Contract)),
        (["Analytics", analytics_path, :analytics] if can?(:read, :analytics)),
        (["Audit", audit_events_path, :audit_events] if can?(:read, AuditEvent)),
        (["Settings", settings_path, :settings] if can?(:read, Setting)),
      ]],
    ]
    groups.map { |label, links| [label, links.compact] }.reject { |_label, links| links.empty? }
  end

  # The page title: what the view set with content_for(:title), else the
  # section name.
  def page_title
    title = content_for?(:title) ? content_for(:title) : controller_name.humanize
    "#{title} · HeatSync Members"
  end
end
