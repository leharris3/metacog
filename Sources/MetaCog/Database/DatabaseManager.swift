import Foundation
import GRDB

@MainActor
final class DatabaseManager: Sendable {
    static let shared = DatabaseManager()

    let dbQueue: DatabaseQueue

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport.appendingPathComponent("MetaCog", isDirectory: true)
        try! FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("metacog.sqlite").path

        var config = Configuration()
        config.foreignKeysEnabled = true
        dbQueue = try! DatabaseQueue(path: dbPath, configuration: config)

        try! migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "task") { t in
                t.primaryKey("id", .text).notNull()
                t.column("title", .text).notNull()
                t.column("justification", .text).notNull()
                t.column("estimatedDuration", .double).notNull().defaults(to: 0)
                t.column("actualDuration", .double).notNull().defaults(to: 0)
                t.column("status", .text).notNull().defaults(to: "planning")
                t.column("createdAt", .datetime).notNull()
                t.column("completedAt", .datetime)
            }

            try db.create(table: "appPermission") { t in
                t.primaryKey("id", .text).notNull()
                t.column("taskId", .text).notNull()
                    .references("task", onDelete: .cascade)
                t.column("bundleIdentifier", .text).notNull()
                t.column("appName", .text).notNull()
                t.column("linkedGroupId", .text)
            }

            try db.create(table: "subGoal") { t in
                t.primaryKey("id", .text).notNull()
                t.column("taskId", .text).notNull()
                    .references("task", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("estimatedDuration", .double).notNull().defaults(to: 0)
                t.column("order", .integer).notNull().defaults(to: 0)
                t.column("completedAt", .datetime)
            }

            try db.create(table: "checkIn") { t in
                t.primaryKey("id", .text).notNull()
                t.column("subGoalId", .text).notNull()
                    .references("subGoal", onDelete: .cascade)
                t.column("timestamp", .datetime).notNull()
                t.column("isCompleted", .boolean).notNull()
                t.column("reflection", .text)
                t.column("foregroundApp", .text).notNull()
                t.column("elapsedTime", .double).notNull()
                t.column("amendmentsMade", .text)
            }

            try db.create(table: "intervention") { t in
                t.primaryKey("id", .text).notNull()
                t.column("taskId", .text).notNull()
                    .references("task", onDelete: .cascade)
                t.column("timestamp", .datetime).notNull()
                t.column("type", .text).notNull()
                t.column("penaltyDuration", .double).notNull()
                t.column("ankiCardId", .text)
                t.column("wasCorrect", .boolean)
                t.column("wasOverridden", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "ankiCard") { t in
                t.primaryKey("id", .text).notNull()
                t.column("front", .text).notNull()
                t.column("back", .text).notNull()
                t.column("easeFactor", .double).notNull().defaults(to: 2.5)
                t.column("interval", .integer).notNull().defaults(to: 0)
                t.column("repetitions", .integer).notNull().defaults(to: 0)
                t.column("nextReviewDate", .datetime).notNull()
            }

            try db.create(table: "taskDebrief") { t in
                t.primaryKey("id", .text).notNull()
                t.column("taskId", .text).notNull()
                    .references("task", onDelete: .cascade)
                t.column("overallOutcome", .text).notNull()
                t.column("subGoalReflectionsJSON", .text).notNull()
                t.column("lessonsLearned", .text).notNull()
            }

            try db.create(table: "dailyOverride") { t in
                t.primaryKey("date", .text).notNull()
                t.column("used", .integer).notNull().defaults(to: 0)
                t.column("limit", .integer).notNull().defaults(to: 3)
            }

            try db.create(table: "appUsageLog") { t in
                t.primaryKey("id", .text).notNull()
                t.column("taskId", .text).notNull()
                    .references("task", onDelete: .cascade)
                t.column("bundleIdentifier", .text).notNull()
                t.column("appName", .text).notNull()
                t.column("startTime", .datetime).notNull()
                t.column("duration", .double).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("seedDeepLearningCards") { db in
            let cards: [(String, String)] = [
                // Optimization Theory
                ("Why does the loss landscape of overparameterized networks have no spurious local minima under certain conditions, and what role does the NTK regime play?",
                 "In the infinite-width (NTK) regime, the loss landscape becomes convex in function space because the kernel remains approximately constant during training. Overparameterization creates a high-dimensional parameter space where all local minima are global (Du et al., 2019; Allen-Zhu et al., 2019). However, this NTK analysis breaks down for feature-learning regimes (μP scaling), where the network leaves the kernel regime and the loss landscape is genuinely non-convex but navigable due to favorable geometry from overparameterization."),

                ("Explain the difference between the lazy training (NTK) regime and the rich/feature-learning (μP) regime. Why does it matter for understanding generalization?",
                 "In the NTK/lazy regime, weights barely move from initialization and the network behaves like a fixed kernel method—it cannot learn features, only combine initial random features linearly. In the rich/μP regime (achieved via maximal update parameterization), feature learning occurs: internal representations adapt to the data. This matters because NTK models generalize like kernel methods (no better than random features), while feature-learning networks achieve superior generalization by learning task-relevant representations. μP also enables hyperparameter transfer across model widths."),

                ("What is the information bottleneck theory of deep learning, and what are its limitations?",
                 "Shwartz-Ziv & Tishby (2017) proposed that DNNs compress input information in hidden layers (fitting phase → compression phase), forming a minimal sufficient statistic of the input for predicting the label. The mutual information I(X;T) decreases while I(T;Y) is preserved. Limitations: (1) compression only reliably occurs with saturating activations (tanh), not ReLU; (2) MI estimation in high dimensions is unreliable; (3) the theory doesn't account for the role of architecture; (4) Saxe et al. showed compression is not causally related to generalization."),

                ("Derive why the Hessian eigenspectrum of neural network loss surfaces typically shows a bulk near zero and a few large outliers. What implications does this have for optimization?",
                 "The Hessian H = J^T J + Σᵢ rᵢ∇²fᵢ. The first (Gauss-Newton) term has rank ≤ min(n, C) where n=samples, C=outputs, giving a low-rank structure. The second term involves residuals that are small near convergence. This creates a spectrum with: (1) a bulk of near-zero eigenvalues spanning the 'flat' directions in parameter space, (2) a few large eigenvalues corresponding to sharp directions. Implications: SGD effectively operates in a low-dimensional subspace; second-order methods need only approximate the top eigenspace; the flat directions enable large learning rates without divergence and connect to favorable generalization (flat minima generalize better per PAC-Bayes bounds)."),

                ("What is the lottery ticket hypothesis, and how does it relate to pruning at initialization (SNIP, GraSP, SynFlow)?",
                 "Frankle & Carlin (2019): dense networks contain sparse subnetworks ('winning tickets') that, when trained in isolation from the same initialization, match the full network's accuracy. Finding tickets requires iterative magnitude pruning (IMP) with weight rewinding. Pruning-at-initialization methods attempt to find good masks without training: SNIP uses connection sensitivity (|∂L/∂m|), GraSP preserves gradient flow (gradient × Hessian-gradient product), SynFlow uses iterative synaptic flow conservation to avoid layer collapse. Key tension: lottery tickets require the specific initialization, while pruning-at-init methods are initialization-agnostic. Empirically, IMP still outperforms pruning-at-init at high sparsity."),

                // Generalization Theory
                ("Why do classical VC/Rademacher complexity bounds fail to explain generalization in deep networks, and what alternatives exist?",
                 "Classical bounds scale with parameter count, predicting no generalization for overparameterized nets. Alternatives: (1) PAC-Bayes bounds: depend on distance from a prior (initialization), explaining why SGD-trained nets generalize (they stay close to init). (2) Compression-based bounds: networks that can be compressed generalize. (3) Norm-based bounds: depend on product of layer norms, not parameter count. (4) Algorithmic stability: SGD's stochasticity limits how much one sample changes the output. (5) Neural tangent kernel bounds in the lazy regime. None are tight enough to be practically predictive, but PAC-Bayes and norm-based approaches capture the right qualitative behavior."),

                ("Explain the double descent phenomenon and how it challenges the classical bias-variance tradeoff.",
                 "Classical U-shaped test error (underfit → sweet spot → overfit) breaks down in modern deep learning. Double descent shows: (1) test error decreases, then increases (classical regime), then decreases again past the interpolation threshold (modern regime). Occurs in model-wise (increasing parameters), epoch-wise (more training), and sample-wise settings. At the interpolation threshold, the model barely fits the training data and is maximally sensitive to noise. Beyond it, overparameterization provides implicit regularization—many interpolating solutions exist and SGD selects smooth ones. Related to Belkin et al.'s reconciliation of interpolation with generalization."),

                ("What is the implicit bias of gradient descent in deep learning, and how does it differ between linear and nonlinear models?",
                 "For linear models, GD on separable data converges in direction to the max-margin (minimum L2 norm) solution. For linear networks (deep matrix factorization), GD implicitly biases toward low-rank solutions—deeper networks prefer lower-rank matrices. For nonlinear networks: (1) GD in homogeneous networks converges to KKT points of a max-margin problem in function space; (2) SGD noise biases toward flat minima (related to the stochastic modified loss that includes a trace-of-Hessian regularizer); (3) The parameterization matters—standard vs μP vs weight normalization yield different implicit biases. This implicit regularization partially explains why explicit regularization is often unnecessary."),

                // Transformers & Attention
                ("Explain the computational and memory complexity of standard self-attention, and describe how FlashAttention achieves exact attention with reduced memory.",
                 "Standard attention: O(n²d) compute, O(n²) memory for the attention matrix. FlashAttention (Dao et al., 2022) exploits GPU memory hierarchy: it tiles Q, K, V into blocks that fit in SRAM, computes attention block-by-block using the online softmax trick (tracking running max and sum), and never materializes the full n×n attention matrix in HBM. This reduces HBM reads/writes from O(n²) to O(n²d²/M) where M is SRAM size. It's IO-aware: the algorithm is exact (not approximate), achieving 2-4x wall-clock speedup purely from reduced memory access. FlashAttention-2 further optimizes by reducing non-matmul FLOPs and improving work partitioning across warps."),

                ("What are mixture-of-experts (MoE) models, and what are the key challenges in training them?",
                 "MoE replaces dense FFN layers with multiple 'expert' FFN sub-networks and a gating/router network that selects top-k experts per token. This decouples parameter count from compute: e.g., Mixtral 8×7B has 47B params but uses ~13B per forward pass. Key challenges: (1) Load balancing—without auxiliary losses, routers collapse to using few experts. Switch Transformer uses a load-balancing loss. (2) Expert parallelism requires all-to-all communication across devices. (3) Training instability—router gradients are noisy; solutions include router z-loss and expert choice routing. (4) Fine-tuning may not activate all experts, wasting capacity. (5) Token dropping during training for load balance hurts quality."),

                ("Explain rotary position embeddings (RoPE) and why they enable length extrapolation better than learned absolute embeddings.",
                 "RoPE (Su et al., 2021) encodes position by rotating query/key vectors in 2D subspaces: for position m, apply rotation matrix R(mθᵢ) to the i-th pair of dimensions, where θᵢ = 10000^(-2i/d). The dot product qᵀk then depends only on relative position (m-n) via the angle difference. Advantages over learned absolute: (1) naturally encodes relative position without separate parameters; (2) decays attention with distance; (3) can extrapolate to longer sequences than seen in training (especially with NTK-aware scaling that adjusts the base frequency, or YaRN which combines NTK scaling with attention temperature). Learned absolute embeddings have no extrapolation mechanism beyond training length."),

                ("What is the KV-cache in autoregressive Transformer inference, and what are the main techniques to reduce its memory footprint?",
                 "During autoregressive generation, each new token attends to all previous tokens. Rather than recomputing K and V for all past tokens, we cache them—but this grows as O(batch × layers × seq_len × d_head). Reduction techniques: (1) Multi-Query Attention (MQA): share K,V heads across query heads (1 KV head per layer). (2) Grouped-Query Attention (GQA): intermediate—G groups of KV heads (Llama 2). (3) Quantization: store KV cache in FP8/INT4. (4) Sliding window attention: limit cache to recent tokens (Mistral). (5) PagedAttention (vLLM): manage cache like virtual memory pages, eliminating fragmentation. (6) Multi-head Latent Attention (MLA, DeepSeek): compress KV into a low-rank latent vector."),

                // Generative Models
                ("Derive the ELBO for VAEs and explain the 'posterior collapse' problem.",
                 "For data x, latent z: log p(x) ≥ E_q(z|x)[log p(x|z)] - KL(q(z|x) || p(z)) = ELBO. The first term is reconstruction quality; the second regularizes the encoder toward the prior. Posterior collapse: the decoder becomes so powerful it ignores z, and q(z|x) collapses to p(z), making KL = 0. The latent space carries no information. Causes: (1) autoregressive decoders can model x without z; (2) KL term is optimized faster than reconstruction. Mitigations: KL annealing (β-VAE warmup), free bits (minimum KL per dimension), δ-VAE (lower-bounding KL), weakening the decoder, or using discrete latents."),

                ("Explain the score matching / denoising diffusion framework. What is the relationship between the score function, Langevin dynamics, and the reverse SDE?",
                 "The score function ∇_x log p(x) points toward high-density regions. Denoising score matching trains a network sθ(xₜ, t) ≈ ∇_x log p_t(x) at each noise level t. The forward process is an SDE: dx = f(x,t)dt + g(t)dw. The reverse process (Anderson, 1982): dx = [f - g²∇_x log pₜ(x)]dt + g(t)dw̄. Replacing the true score with the learned sθ gives a generative reverse SDE. Ancestral sampling is the discrete Euler-Maruyama discretization. The DDPM loss ||ε - εθ(xₜ, t)||² is equivalent to denoising score matching (up to weighting). Probability flow ODE (deterministic) enables exact likelihood computation and interpolation."),

                ("What is classifier-free guidance and why does it work better than classifier guidance for conditional generation?",
                 "Classifier guidance: ∇_x log p(x|c) = ∇_x log p(x) + γ·∇_x log p(c|x), requiring a separate noisy classifier. Classifier-free guidance (Ho & Salimans, 2022): jointly train conditional and unconditional models (drop conditioning with probability p_uncond), then extrapolate: ε̃ = εθ(x,∅) + w·(εθ(x,c) - εθ(x,∅)). When w > 1, this moves away from unconditional toward conditional—effectively sharpening p(c|x). Advantages: no separate classifier needed, the same model provides both terms, empirically produces higher-fidelity results. It works because the extrapolation implicitly increases the log-likelihood ratio log p(c|x)/p(c), concentrating samples where conditioning is most satisfied."),

                // Training at Scale
                ("Explain the different forms of parallelism used to train large language models: data, tensor, pipeline, and sequence parallelism.",
                 "Data parallelism (DP/FSDP): replicate model across GPUs, split batches, all-reduce gradients. FSDP shards optimizer states + weights across GPUs, gathering for each layer's forward/backward. Tensor parallelism (TP): split individual layer weights across GPUs (e.g., column-split for first linear, row-split for second in FFN). Requires all-reduce per layer—needs fast interconnect (NVLink). Pipeline parallelism (PP): assign different layers to different GPUs, micro-batch pipelining to reduce bubble time. 1F1B schedule minimizes memory. Sequence parallelism (SP): for very long sequences, split the sequence dimension across GPUs in non-attention layers (LayerNorm, dropout), complementing TP. Ring Attention extends this to attention itself. Megatron-LM combines all four; optimal mapping depends on cluster topology."),

                ("What is the chinchilla scaling law, and how does it differ from the original Kaplan et al. scaling laws?",
                 "Kaplan et al. (2020): L(N,D) ∝ N^(-αN) + D^(-αD) with αN ≈ 0.076, αD ≈ 0.095, suggesting models should be scaled much faster than data (N grows ~5.5x for every 2x data). Chinchilla (Hoffmann et al., 2022): reanalyzed and found αN ≈ αD ≈ 0.34—parameters and tokens should scale equally. For compute-optimal training: N ∝ C^0.5, D ∝ C^0.5. The 70B Chinchilla matched 280B Gopher with 4x less compute by using 4x more data. Practical implication: most LLMs pre-Chinchilla were undertrained. Post-Chinchilla (Llama, etc.) uses even more tokens than Chinchilla-optimal because inference cost favors smaller, more-trained models."),

                ("Explain the RLHF pipeline for aligning language models. What are the failure modes of reward modeling, and how does DPO address them?",
                 "RLHF: (1) SFT on demonstrations, (2) train reward model on human preference pairs, (3) optimize policy via PPO against reward model with KL penalty to SFT policy. Reward model failure modes: reward hacking (policy exploits reward model weaknesses), distributional shift (RM trained on SFT outputs, evaluated on PPO outputs), inconsistent human preferences, and reward model overoptimization (Gao et al. scaling law: performance peaks then degrades as KL increases). DPO (Rafailov et al., 2023) eliminates the explicit reward model by showing the optimal policy under the RLHF objective has a closed-form relationship to the reward: r(x,y) = β log(π(y|x)/π_ref(y|x)) + f(x). This gives a loss directly on preference pairs using the policy itself, avoiding reward model training and PPO instability."),

                ("What is the grokking phenomenon, and what theories explain the transition from memorization to generalization?",
                 "Grokking (Power et al., 2022): on small algorithmic datasets, models first memorize (100% train, ~random test), then much later suddenly generalize (test accuracy jumps to 100%). Theories: (1) Weight decay slowly compresses representations, eventually finding generalizing circuits (Neel Nanda's mechanistic analysis found clean modular arithmetic circuits). (2) Slow feature learning: generalizing features are learned throughout but initially overwhelmed by memorizing features; weight decay gradually kills memorization. (3) Structured vs unstructured components compete—unstructured memorization has higher norm and decays. (4) Phase transitions in representation learning—the network discovers a symmetry. Related to double descent and the observation that implicit/explicit regularization steers toward generalizing solutions on longer timescales."),

                // Theory of Representations
                ("What is the manifold hypothesis, and how does it justify deep learning architectures?",
                 "The manifold hypothesis posits that high-dimensional real-world data (images, text) lies on or near low-dimensional manifolds embedded in the ambient space. Deep networks learn hierarchical, progressively unfolding transformations of these manifolds. This justifies: (1) why deep networks need far fewer parameters than the ambient dimension suggests; (2) why layer-wise feature extraction works (each layer unfolds the manifold further); (3) why interpolation in latent space produces meaningful outputs; (4) why generalization is possible despite the curse of dimensionality. Empirical evidence: intrinsic dimensionality of learned representations is much lower than the embedding dimension; GAN latent spaces produce smooth interpolations."),

                ("Explain the connection between attention, kernel methods, and Hopfield networks.",
                 "Modern Hopfield networks (Ramsauer et al., 2021) show that Transformer attention is equivalent to the update rule of a continuous Hopfield network with exponential (softmax) energy. Stored patterns = keys/values, query = state. The softmax attention retrieves the value associated with the key most similar to the query—a content-addressable memory operation. Connection to kernels: attention computes softmax(QKᵀ/√d), which approximates exp(q·k/√d), an RBF-like kernel. Random feature approximations of this kernel yield linear attention variants (Performers). This unifying view explains: attention as associative memory retrieval, the capacity of Transformers (exponential in d for Hopfield), and why attention matrices are often nearly low-rank."),

                ("What is mechanistic interpretability, and what are the key findings about how Transformers implement algorithms internally?",
                 "Mechanistic interpretability reverse-engineers neural network computations into human-understandable algorithms. Key findings: (1) Induction heads: pairs of attention heads (one copies, one matches patterns) that implement in-context learning via pattern completion. (2) Modular arithmetic circuits: grokked models learn Fourier-based representations with clean circular structure. (3) Superposition: networks represent more features than dimensions by encoding rarely-co-active features in overlapping directions (related to compressed sensing). (4) Indirect object identification: multi-step circuits involving >25 heads with backup/redundancy. (5) Features as directions in activation space, organized in feature families. Tools: activation patching, causal tracing, sparse autoencoders for feature extraction. Major open question: does superposition prevent clean decomposition of large models?"),

                ("What is the theoretical basis for why depth is more powerful than width in neural networks?",
                 "Multiple formal results: (1) Depth separation theorems: functions computable by poly-size depth-k networks require exponential width at depth k-1 (Telgarsky, 2016: oscillatory functions; Eldan-Shamir, 2016: radial functions). (2) Deep networks compose features hierarchically, achieving exponential efficiency for compositional functions (tensor decomposition view). (3) The number of linear regions in ReLU networks grows exponentially with depth but polynomially with width. (4) Deep networks can represent the same function class with exponentially fewer parameters. However: (5) optimization difficulty increases with depth (vanishing gradients, shattered gradients). (6) Residual connections mitigate this, allowing effective depth to adapt. (7) In practice, very wide shallow networks can approximate deep ones but with much worse sample complexity."),
            ]

            for (front, back) in cards {
                let card = AnkiCard(front: front, back: back)
                try card.insert(db)
            }
        }

        migrator.registerMigration("fixAnkiCardUUIDs") { db in
            // The original seed migration stored UUIDs as text strings via raw SQL.
            // GRDB 7 encodes UUIDs as 16-byte blobs, so update(db) used a blob WHERE
            // clause that never matched the text rows — silently failing on every review.
            // Re-insert any text-UUID rows using GRDB's ORM so UUIDs are stored as blobs.
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM ankiCard WHERE typeof(id) = 'text'")
            for row in rows {
                let idString: String = row["id"]
                guard let uuid = UUID(uuidString: idString) else { continue }
                try db.execute(sql: "DELETE FROM ankiCard WHERE id = ?", arguments: [idString])
                let card = AnkiCard(
                    id: uuid,
                    front: row["front"],
                    back: row["back"],
                    easeFactor: row["easeFactor"],
                    interval: row["interval"],
                    repetitions: row["repetitions"],
                    nextReviewDate: row["nextReviewDate"]
                )
                try card.insert(db)
            }
        }

        return migrator
    }

    // MARK: - Task CRUD

    func createTask(_ task: TaskRecord) throws {
        try dbQueue.write { db in
            try task.insert(db)
        }
    }

    func fetchTask(id: UUID) throws -> TaskRecord? {
        try dbQueue.read { db in
            try TaskRecord.fetchOne(db, key: id)
        }
    }

    func fetchAllTasks() throws -> [TaskRecord] {
        try dbQueue.read { db in
            try TaskRecord.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    func fetchActiveTask() throws -> TaskRecord? {
        try dbQueue.read { db in
            try TaskRecord.filter(Column("status") == TaskStatus.active.rawValue).fetchOne(db)
        }
    }

    func fetchPausedTask() throws -> TaskRecord? {
        try dbQueue.read { db in
            try TaskRecord
                .filter(Column("status") == TaskStatus.active.rawValue || Column("status") == TaskStatus.paused.rawValue)
                .fetchOne(db)
        }
    }

    func updateTask(_ task: TaskRecord) throws {
        try dbQueue.write { db in
            try task.update(db)
        }
    }

    func deleteTask(id: UUID) throws {
        try dbQueue.write { db in
            _ = try TaskRecord.deleteOne(db, key: id)
        }
    }

    // MARK: - AppPermission CRUD

    func createAppPermission(_ perm: AppPermission) throws {
        try dbQueue.write { db in
            try perm.insert(db)
        }
    }

    func fetchAppPermissions(forTask taskId: UUID) throws -> [AppPermission] {
        try dbQueue.read { db in
            try AppPermission.filter(Column("taskId") == taskId).fetchAll(db)
        }
    }

    func deleteAppPermission(id: UUID) throws {
        try dbQueue.write { db in
            _ = try AppPermission.deleteOne(db, key: id)
        }
    }

    func updateAppPermission(_ perm: AppPermission) throws {
        try dbQueue.write { db in
            try perm.update(db)
        }
    }

    // MARK: - SubGoal CRUD

    func createSubGoal(_ goal: SubGoal) throws {
        try dbQueue.write { db in
            try goal.insert(db)
        }
    }

    func fetchSubGoals(forTask taskId: UUID) throws -> [SubGoal] {
        try dbQueue.read { db in
            try SubGoal.filter(Column("taskId") == taskId).order(Column("order")).fetchAll(db)
        }
    }

    func updateSubGoal(_ goal: SubGoal) throws {
        try dbQueue.write { db in
            try goal.update(db)
        }
    }

    func deleteSubGoal(id: UUID) throws {
        try dbQueue.write { db in
            _ = try SubGoal.deleteOne(db, key: id)
        }
    }

    // MARK: - CheckIn CRUD

    func createCheckIn(_ checkIn: CheckIn) throws {
        try dbQueue.write { db in
            try checkIn.insert(db)
        }
    }

    func fetchCheckIns(forSubGoal subGoalId: UUID) throws -> [CheckIn] {
        try dbQueue.read { db in
            try CheckIn.filter(Column("subGoalId") == subGoalId).order(Column("timestamp")).fetchAll(db)
        }
    }

    // MARK: - Intervention CRUD

    func createIntervention(_ intervention: Intervention) throws {
        try dbQueue.write { db in
            try intervention.insert(db)
        }
    }

    func fetchInterventions(forTask taskId: UUID) throws -> [Intervention] {
        try dbQueue.read { db in
            try Intervention.filter(Column("taskId") == taskId).order(Column("timestamp")).fetchAll(db)
        }
    }

    func fetchInterventionsThisWeek() throws -> [Intervention] {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return try dbQueue.read { db in
            try Intervention.filter(Column("timestamp") >= weekStart).fetchAll(db)
        }
    }

    // MARK: - AnkiCard CRUD

    func createAnkiCard(_ card: AnkiCard) throws {
        try dbQueue.write { db in
            try card.insert(db)
        }
    }

    func fetchAllAnkiCards() throws -> [AnkiCard] {
        try dbQueue.read { db in
            try AnkiCard.fetchAll(db)
        }
    }

    func fetchDueAnkiCards() throws -> [AnkiCard] {
        try dbQueue.read { db in
            try AnkiCard.filter(Column("nextReviewDate") <= Date()).fetchAll(db)
        }
    }

    func updateAnkiCard(_ card: AnkiCard) throws {
        try dbQueue.write { db in
            try card.update(db)
        }
    }

    func deleteAnkiCard(id: UUID) throws {
        try dbQueue.write { db in
            _ = try AnkiCard.deleteOne(db, key: id)
        }
    }

    // MARK: - TaskDebrief CRUD

    func createDebrief(_ debrief: TaskDebrief) throws {
        try dbQueue.write { db in
            try debrief.insert(db)
        }
    }

    func fetchDebrief(forTask taskId: UUID) throws -> TaskDebrief? {
        try dbQueue.read { db in
            try TaskDebrief.filter(Column("taskId") == taskId).fetchOne(db)
        }
    }

    // MARK: - DailyOverride

    func fetchOrCreateDailyOverride(for date: Date = Date()) throws -> DailyOverride {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: date)

        return try dbQueue.write { db in
            if let existing = try DailyOverride.fetchOne(db, key: dateKey) {
                return existing
            }
            let newOverride = DailyOverride(date: date)
            try newOverride.insert(db)
            return newOverride
        }
    }

    func useOverride(for date: Date = Date()) throws -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: date)

        return try dbQueue.write { db in
            var override = try DailyOverride.fetchOne(db, key: dateKey) ?? DailyOverride(date: date)
            guard override.hasOverridesRemaining else { return false }
            override.used += 1
            try override.save(db)
            return true
        }
    }

    // MARK: - AppUsageLog CRUD

    func createAppUsageLog(_ log: AppUsageLog) throws {
        try dbQueue.write { db in
            try log.insert(db)
        }
    }

    func updateAppUsageLog(_ log: AppUsageLog) throws {
        try dbQueue.write { db in
            try log.update(db)
        }
    }

    func fetchAppUsageLogs(forTask taskId: UUID) throws -> [AppUsageLog] {
        try dbQueue.read { db in
            try AppUsageLog.filter(Column("taskId") == taskId).fetchAll(db)
        }
    }

    // MARK: - Analytics Queries

    func fetchTasksCompletedThisWeek() throws -> [TaskRecord] {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return try dbQueue.read { db in
            try TaskRecord
                .filter(Column("completedAt") != nil && Column("completedAt") >= weekStart)
                .filter(Column("status") == TaskStatus.completed.rawValue || Column("status") == TaskStatus.abandoned.rawValue)
                .fetchAll(db)
        }
    }

    func fetchTotalActiveTimeThisWeek() throws -> TimeInterval {
        let tasks = try fetchTasksCompletedThisWeek()
        return tasks.reduce(0) { $0 + $1.actualDuration }
    }

    func fetchDailyActiveTime(for week: Date = Date()) throws -> [(date: String, duration: TimeInterval)] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: week) else { return [] }

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT date(completedAt) as day, SUM(actualDuration) as total
                FROM task
                WHERE completedAt >= ? AND completedAt < ?
                  AND status IN ('completed', 'abandoned')
                GROUP BY date(completedAt)
                ORDER BY day
                """, arguments: [weekInterval.start, weekInterval.end])

            return rows.map { row in
                (date: row["day"] as String, duration: row["total"] as TimeInterval)
            }
        }
    }
}
