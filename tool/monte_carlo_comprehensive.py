import random
import json

def run_multi_seed_simulation(runs=10, n_users=1000):
    two_button_dropoffs = []
    two_button_completions = []
    two_button_confusion = []
    two_button_restored = []
    two_button_stalled = []

    one_button_dropoffs = []
    one_button_completions = []
    one_button_confusion = []
    one_button_restored = []
    one_button_stalled = []

    for seed in range(runs):
        random.seed(seed * 1007 + 42)
        users = []
        for i in range(n_users):
            r = random.random()
            if r < 0.55:
                user_type = "new_tradie"
                has_account = False
                tech_comfort = random.uniform(0.2, 0.6)
                fatigue = random.uniform(0.6, 0.95)
            elif r < 0.80:
                user_type = "returning_tradie"
                has_account = True
                tech_comfort = random.uniform(0.3, 0.7)
                fatigue = random.uniform(0.5, 0.9)
            elif r < 0.95:
                user_type = "skeptical_guest"
                has_account = False
                tech_comfort = random.uniform(0.4, 0.8)
                fatigue = random.uniform(0.3, 0.7)
            else:
                user_type = "confused_lapsed"
                has_account = random.choice([True, False])
                tech_comfort = random.uniform(0.1, 0.4)
                fatigue = random.uniform(0.7, 0.99)
            users.append({
                "id": i, "type": user_type, "has_account": has_account,
                "tech_comfort": tech_comfort, "fatigue": fatigue
            })
        
        # 2-Button simulation
        w_drop_2, s_comp_2, r_conf_2, ret_rest_2, ret_stall_2 = 0, 0, 0, 0, 0
        for u in users:
            p_drop_welcome = 0.04 + 0.05 * (1.0 - u["tech_comfort"]) * u["fatigue"]
            if random.random() < p_drop_welcome:
                w_drop_2 += 1
                continue
            if u["has_account"]:
                p_see_signin = 0.85 + 0.10 * u["tech_comfort"]
                if random.random() < p_see_signin:
                    p_auth = 0.94 - 0.05 * u["fatigue"]
                    if random.random() < p_auth:
                        s_comp_2 += 1
                        if random.random() < 0.08:
                            ret_stall_2 += 1
                            r_conf_2 += 1
                        else:
                            ret_rest_2 += 1
                    else:
                        ret_stall_2 += 1
                else:
                    r_conf_2 += 1
                    ret_stall_2 += 1
            else:
                if random.random() < 0.06:
                    r_conf_2 += 1
                    if random.random() < 0.65:
                        s_comp_2 += 1
                    else:
                        w_drop_2 += 1
                else:
                    s_comp_2 += 1
                    
        two_button_dropoffs.append(w_drop_2)
        two_button_completions.append(s_comp_2)
        two_button_confusion.append(r_conf_2)
        two_button_restored.append(ret_rest_2)
        two_button_stalled.append(ret_stall_2)

        # 1-Button simulation
        w_drop_1, s_comp_1, r_conf_1, ret_rest_1, ret_stall_1 = 0, 0, 0, 0, 0
        for u in users:
            p_drop_welcome = 0.02 + (0.015 if u["has_account"] else 0.0) * u["fatigue"]
            if random.random() < p_drop_welcome:
                w_drop_1 += 1
                continue
            if u["has_account"]:
                p_auth = 0.96 - 0.03 * u["fatigue"]
                if random.random() < p_auth:
                    s_comp_1 += 1
                    ret_rest_1 += 1
                else:
                    ret_stall_1 += 1
                    if random.random() < 0.2:
                        r_conf_1 += 1
            else:
                if u["type"] == "skeptical_guest":
                    s_comp_1 += 1
                else:
                    p_proceed = 0.95 - 0.04 * u["fatigue"]
                    if random.random() < p_proceed:
                        s_comp_1 += 1
                    else:
                        w_drop_1 += 1
                        
        one_button_dropoffs.append(w_drop_1)
        one_button_completions.append(s_comp_1)
        one_button_confusion.append(r_conf_1)
        one_button_restored.append(ret_rest_1)
        one_button_stalled.append(ret_stall_1)

    def mean(lst): return sum(lst) / len(lst)
    
    print("Aggregate Results over 10 independent Monte Carlo iterations (10,000 synthetic journeys):")
    print(f"2-Button Welcome Drop-Off Mean: {mean(two_button_dropoffs):.1f} ({mean(two_button_dropoffs)/10:.1f}%)")
    print(f"1-Button Welcome Drop-Off Mean: {mean(one_button_dropoffs):.1f} ({mean(one_button_dropoffs)/10:.1f}%)")
    print(f"2-Button Sign-In Completion Mean: {mean(two_button_completions):.1f} ({mean(two_button_completions)/10:.1f}%)")
    print(f"1-Button Sign-In Completion Mean: {mean(one_button_completions):.1f} ({mean(one_button_completions)/10:.1f}%)")
    print(f"2-Button Routing Confusion Errors Mean: {mean(two_button_confusion):.1f}")
    print(f"1-Button Routing Confusion Errors Mean: {mean(one_button_confusion):.1f}")
    print(f"2-Button Returning Users Stalled/Mishandled: {mean(two_button_stalled):.1f}")
    print(f"1-Button Returning Users Stalled/Mishandled: {mean(one_button_stalled):.1f}")

if __name__ == "__main__":
    run_multi_seed_simulation()
